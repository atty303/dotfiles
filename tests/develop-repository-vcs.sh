#!/bin/sh
set -eu

repo_root=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
vcs_script=$repo_root/home/dot_agents/skills/develop-repository/scripts/executable_vcs.sh
push_script=$repo_root/home/dot_agents/skills/develop-repository/scripts/executable_vcs-push.sh
rules_template=$repo_root/home/dot_codex/rules/vcs.rules.tmpl
github_rules=$repo_root/home/dot_codex/rules/github-read.rules
test_root=$(mktemp -d "${TMPDIR:-/tmp}/develop-repository-vcs.XXXXXX")

cleanup() {
    rm -rf -- "$test_root"
}

trap cleanup EXIT HUP INT TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    file=$1
    text=$2
    grep -F -- "$text" "$file" >/dev/null || fail "$file does not contain: $text"
}

assert_not_contains() {
    file=$1
    text=$2
    if grep -F -- "$text" "$file" >/dev/null; then
        fail "$file unexpectedly contains: $text"
    fi
}

if command -v chezmoi >/dev/null 2>&1 && command -v codex >/dev/null 2>&1; then
    rendered_rules=$test_root/vcs.rules
    chezmoi execute-template <"$rules_template" >"$rendered_rules"
    wrapper_path=$HOME/.agents/skills/develop-repository/scripts/vcs.sh
    push_wrapper_path=$HOME/.agents/skills/develop-repository/scripts/vcs-push.sh
    codex execpolicy check --rules "$rendered_rules" --pretty "$wrapper_path" snapshot >"$test_root/vcs-policy.txt" 2>&1
    codex execpolicy check --rules "$rendered_rules" --pretty "$push_wrapper_path" ssh feature/example >"$test_root/push-policy.txt" 2>&1
    codex execpolicy check --rules "$rendered_rules" --pretty "$push_wrapper_path" origin --change @ >"$test_root/push-change-policy.txt" 2>&1
    codex execpolicy check --rules "$github_rules" --pretty gh pr list --repo openai/codex >"$test_root/gh-pr-list-policy.txt" 2>&1
    codex execpolicy check --rules "$github_rules" --pretty gh pr view 123 >"$test_root/gh-pr-view-policy.txt" 2>&1
    codex execpolicy check --rules "$github_rules" --pretty gh pr create >"$test_root/gh-pr-create-policy.txt" 2>&1
    codex execpolicy check --rules "$github_rules" --pretty gh pr merge 123 >"$test_root/gh-pr-merge-policy.txt" 2>&1
    assert_contains "$test_root/vcs-policy.txt" '"decision": "allow"'
    assert_contains "$test_root/push-policy.txt" '"matchedRules": []'
    assert_contains "$test_root/push-change-policy.txt" '"matchedRules": []'
    assert_contains "$test_root/gh-pr-list-policy.txt" '"decision": "allow"'
    assert_contains "$test_root/gh-pr-view-policy.txt" '"decision": "allow"'
    assert_contains "$test_root/gh-pr-create-policy.txt" '"matchedRules": []'
    assert_contains "$test_root/gh-pr-merge-policy.txt" '"matchedRules": []'
else
    echo 'SKIP: chezmoi or codex is unavailable; VCS policy tests skipped'
fi

init_git_repo() {
    path=$1
    git init -q "$path"
    git -C "$path" config user.name Test
    git -C "$path" config user.email test@example.com
    printf 'base\n' >"$path/tracked.txt"
    git -C "$path" add tracked.txt
    git -C "$path" commit -qm base
    git -C "$path" branch -M main
}

git_repo=$test_root/git
git_remote=$test_root/git-remote.git
git init -q --bare "$git_remote"
init_git_repo "$git_repo"
git -C "$git_repo" remote add origin "$git_remote"
git -C "$git_repo" push -qu origin main
printf 'staged\n' >"$git_repo/staged.txt"
git -C "$git_repo" add staged.txt
printf 'unstaged\n' >>"$git_repo/tracked.txt"
printf 'untracked\n' >"$git_repo/untracked.txt"
git_snapshot=$test_root/git-snapshot.txt
(cd "$git_repo" && sh "$vcs_script" snapshot --fetch origin) >"$git_snapshot" 2>&1
assert_contains "$git_snapshot" 'vcs=git'
assert_contains "$git_snapshot" 'fetch_status=succeeded'
assert_contains "$git_snapshot" 'current_line=main'
assert_contains "$git_snapshot" 'head='
assert_contains "$git_snapshot" 'parent_commit='
assert_contains "$git_snapshot" 'ahead=0'
assert_contains "$git_snapshot" 'behind=0'
assert_contains "$git_snapshot" 'staged_changes:'
assert_contains "$git_snapshot" 'A'
assert_contains "$git_snapshot" 'staged.txt'
assert_contains "$git_snapshot" 'unstaged_changes:'
assert_contains "$git_snapshot" 'tracked.txt'
assert_contains "$git_snapshot" 'untracked_changes:'
assert_contains "$git_snapshot" 'untracked.txt'

git -C "$git_repo" reset -q HEAD -- staged.txt
git_no_staged_snapshot=$test_root/git-no-staged-snapshot.txt
(cd "$git_repo" && sh "$vcs_script" snapshot) >"$git_no_staged_snapshot" 2>&1
assert_contains "$git_no_staged_snapshot" 'staged_changes:'
assert_contains "$git_no_staged_snapshot" '  (none)'
assert_contains "$git_no_staged_snapshot" 'unstaged_changes:'
assert_contains "$git_no_staged_snapshot" 'staged.txt'
assert_contains "$git_no_staged_snapshot" 'untracked_changes:'
assert_contains "$git_no_staged_snapshot" 'untracked.txt'
git -C "$git_repo" add staged.txt

printf 'selected\n' >"$git_repo/selected.txt"
(cd "$git_repo" && sh "$vcs_script" commit -m 'test: selected git path' -- selected.txt)
git -C "$git_repo" diff-tree --no-commit-id --name-only -r HEAD >"$test_root/git-commit-paths.txt"
[ "$(cat "$test_root/git-commit-paths.txt")" = 'selected.txt' ] || fail 'Git path commit included unrelated files'
git -C "$git_repo" diff --cached --name-only >"$test_root/git-staged.txt"
assert_contains "$test_root/git-staged.txt" 'staged.txt'
git -C "$git_repo" log -1 --format=%B >"$test_root/git-message.txt"
assert_contains "$test_root/git-message.txt" 'Co-authored-by: Codex <codex@openai.com>'

git -C "$git_repo" branch private
(cd "$git_repo" && sh "$push_script" origin main)
git --git-dir="$git_remote" show-ref >"$test_root/git-remote-refs.txt"
assert_contains "$test_root/git-remote-refs.txt" 'refs/heads/main'
assert_not_contains "$test_root/git-remote-refs.txt" 'refs/heads/private'
[ "$(git --git-dir="$git_remote" rev-parse refs/heads/main)" = "$(git -C "$git_repo" rev-parse main)" ] || fail 'push did not update the requested Git branch'

git -C "$git_repo" remote set-url origin "$test_root/missing-remote.git"
fetch_failure=$test_root/fetch-failure.txt
set +e
(cd "$git_repo" && sh "$vcs_script" snapshot --fetch origin) >"$fetch_failure" 2>&1
fetch_status=$?
set -e
[ "$fetch_status" -eq 2 ] || fail "fetch failure exited with $fetch_status instead of 2"
assert_contains "$fetch_failure" 'fetch_status=failed'
assert_contains "$fetch_failure" 'current_commit='
assert_contains "$fetch_failure" 'staged_changes:'

if command -v jj >/dev/null 2>&1; then
    jj_repo=$test_root/jj
    init_git_repo "$jj_repo"
    jj git init --colocate "$jj_repo" >/dev/null
    printf 'selected\n' >"$jj_repo/selected.txt"
    printf 'unrelated\n' >"$jj_repo/unrelated.txt"
    jj_snapshot=$test_root/jj-snapshot.txt
    (cd "$jj_repo" && sh "$vcs_script" snapshot) >"$jj_snapshot" 2>&1
    assert_contains "$jj_snapshot" 'vcs=jj'
    assert_contains "$jj_snapshot" 'workspace_status=current'
    assert_contains "$jj_snapshot" 'working_copy='
    assert_contains "$jj_snapshot" ' change='
    assert_contains "$jj_snapshot" 'current_change_empty=false'
    assert_contains "$jj_snapshot" 'parent_commit='
    assert_contains "$jj_snapshot" 'change_paths:'
    assert_contains "$jj_snapshot" 'selected.txt'
    assert_contains "$jj_snapshot" 'unrelated.txt'
    assert_contains "$jj_snapshot" 'bookmarks:'

    (cd "$jj_repo" && sh "$vcs_script" commit -m 'test: selected jj path' -- selected.txt)
    jj -R "$jj_repo" diff --summary -r @- >"$test_root/jj-committed.txt"
    jj -R "$jj_repo" diff --summary -r @ >"$test_root/jj-working.txt"
    assert_contains "$test_root/jj-committed.txt" 'selected.txt'
    assert_not_contains "$test_root/jj-committed.txt" 'unrelated.txt'
    assert_contains "$test_root/jj-working.txt" 'unrelated.txt'
    jj -R "$jj_repo" log --no-graph -r @- -T description >"$test_root/jj-message.txt"
    assert_contains "$test_root/jj-message.txt" 'Co-authored-by: Codex <codex@openai.com>'

    stale_repo=$test_root/stale
    stale_other=$test_root/stale-other
    init_git_repo "$stale_repo"
    jj git init --colocate "$stale_repo" >/dev/null
    printf 'workspace-a\n' >"$stale_repo/a.txt"
    jj -R "$stale_repo" status >/dev/null
    jj -R "$stale_repo" workspace add "$stale_other" >/dev/null
    printf 'workspace-b\n' >"$stale_other/b.txt"
    jj -R "$stale_other" commit -m 'workspace B' >/dev/null
    stale_commit=$(jj -R "$stale_repo" log --ignore-working-copy --no-graph -r @ -T commit_id)
    other_parent=$(jj -R "$stale_other" log --ignore-working-copy --no-graph -r @- -T commit_id)
    jj -R "$stale_other" rebase -r "$stale_commit" -d "$other_parent" >/dev/null
    [ ! -e "$stale_repo/b.txt" ] || fail 'stale fixture unexpectedly updated workspace A'
    printf '[snapshot]\nauto-update-stale = true\n' >"$test_root/jj-config.toml"
    stale_snapshot=$test_root/stale-snapshot.txt
    set +e
    (cd "$stale_repo" && JJ_CONFIG="$test_root/jj-config.toml" sh "$vcs_script" snapshot) >"$stale_snapshot" 2>&1
    stale_status=$?
    set -e
    [ "$stale_status" -eq 3 ] || fail "stale workspace exited with $stale_status instead of 3"
    assert_contains "$stale_snapshot" 'workspace_status=stale'
    assert_contains "$stale_snapshot" 'next_action=inspect the stale workspace'
    [ ! -e "$stale_repo/b.txt" ] || fail 'snapshot automatically updated the stale workspace'
    stale_before=$(jj -R "$stale_repo" log --ignore-working-copy --no-graph -r @ -T commit_id)
    set +e
    (cd "$stale_repo" && JJ_CONFIG="$test_root/jj-config.toml" sh "$vcs_script" commit -m 'test: reject stale commit' -- a.txt) >"$test_root/stale-commit.txt" 2>&1
    stale_commit_status=$?
    set -e
    [ "$stale_commit_status" -ne 0 ] || fail 'commit automatically updated a stale workspace'
    stale_after=$(jj -R "$stale_repo" log --ignore-working-copy --no-graph -r @ -T commit_id)
    [ "$stale_before" = "$stale_after" ] || fail 'rejected stale commit changed the working-copy commit'
    [ ! -e "$stale_repo/b.txt" ] || fail 'commit automatically updated the stale workspace files'
else
    echo 'SKIP: jj is unavailable; Git VCS tests passed'
fi

echo 'develop-repository VCS tests passed'
