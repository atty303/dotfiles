#!/bin/sh
set -eu

coauthor='Co-authored-by: Codex <codex@openai.com>'
fetch_status=not_requested
fetch_result=0
status_file=

cleanup() {
    if [ -n "$status_file" ]; then
        rm -f -- "$status_file"
    fi
}

trap cleanup EXIT HUP INT TERM

usage() {
    cat >&2 <<'EOF'
usage:
  vcs.sh snapshot [--fetch [REMOTE]]
  vcs.sh commit -m MESSAGE (--all | -- PATH...)
EOF
    exit 64
}

detect_vcs() {
    if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
        vcs=jj
    elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
        vcs=git
    else
        echo 'not inside a jj or Git repository' >&2
        exit 1
    fi
}

jj_snapshot() {
    jj --config snapshot.auto-update-stale=false "$@"
}

fetch_remote() {
    remote=${1-}
    case $vcs in
        jj)
            if [ -n "$remote" ]; then
                jj_snapshot git fetch --remote "$remote"
            else
                jj_snapshot git fetch
            fi
            ;;
        git)
            if [ -n "$remote" ]; then
                git fetch "$remote"
            else
                git fetch
            fi
            ;;
    esac
}

snapshot() {
    requested_remote=${1-}
    echo "vcs=$vcs"
    case $vcs in
        jj)
            echo "root=$(jj root)"
            echo "fetch_status=$fetch_status"
            status_file=$(mktemp "${TMPDIR:-/tmp}/vcs-status.XXXXXX")
            if ! jj_snapshot status >"$status_file" 2>&1; then
                if grep -Eiq 'working copy.*stale|stale working copy' "$status_file"; then
                    echo 'workspace_status=stale'
                    sed 's/^/workspace_error=/' "$status_file"
                    echo 'next_action=inspect the stale workspace and run jj workspace update-stale only after confirming its impact'
                    return 3
                fi
                cat "$status_file" >&2
                return 1
            fi
            echo 'workspace_status=current'
            jj_snapshot log --no-graph -r @ -T '"working_copy=" ++ commit_id ++ " change=" ++ change_id ++ "\ncurrent_commit=" ++ commit_id ++ "\ncurrent_change=" ++ change_id ++ "\ncurrent_change_empty=" ++ if(empty, "true", "false") ++ "\ncurrent_line=" ++ bookmarks ++ "\n"'
            if jj_snapshot log --no-graph -r @- -T '"parent_commit=" ++ commit_id ++ "\nparent_change=" ++ change_id ++ "\n"'; then
                :
            else
                echo 'parent_commit=unresolved'
                echo 'parent_change=unresolved'
            fi
            echo 'change_paths:'
            if jj_snapshot diff --summary >"$status_file"; then
                if [ -s "$status_file" ]; then
                    sed 's/^/  /' "$status_file"
                else
                    echo '  (none)'
                fi
            else
                cat "$status_file" >&2
                return 1
            fi
            echo 'bookmarks:'
            jj_snapshot bookmark list --all-remotes
            echo 'remotes:'
            jj_snapshot git remote list | awk '{ print $1 }'
            if ! jj_snapshot log --no-graph -r 'trunk()' -T '"default_line=" ++ commit_id ++ "\n"'; then
                echo 'default_line=unresolved'
            fi
            ;;
        git)
            echo "root=$(git rev-parse --show-toplevel)"
            echo "fetch_status=$fetch_status"
            status_file=$(mktemp "${TMPDIR:-/tmp}/vcs-status.XXXXXX")
            git status --short --branch
            if [ -n "$(git status --porcelain)" ]; then
                echo 'working_state=dirty'
            else
                echo 'working_state=clean'
            fi
            if current_line=$(git symbolic-ref --quiet --short HEAD 2>/dev/null); then
                echo "current_line=$current_line"
            else
                echo 'current_line=detached'
            fi
            echo 'remotes:'
            git remote
            if head=$(git rev-parse --verify HEAD 2>/dev/null); then
                echo "head=$head"
                echo "current_commit=$head"
            else
                echo 'head=unborn'
                echo 'current_commit=unborn'
            fi
            if parent=$(git rev-parse --verify HEAD^ 2>/dev/null); then
                echo "parent_commit=$parent"
            else
                echo 'parent_commit=unresolved'
            fi
            upstream=
            if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
                echo "upstream=$upstream"
                counts=$(git rev-list --left-right --count "HEAD...$upstream")
                ahead=${counts%%[[:space:]]*}
                behind=${counts##*[[:space:]]}
                echo "ahead=$ahead"
                echo "behind=$behind"
            else
                echo 'upstream=unconfigured'
                echo 'ahead=unresolved'
                echo 'behind=unresolved'
            fi
            remote_name=$requested_remote
            if [ -z "$remote_name" ]; then
                remote_name=${upstream%%/*}
                if [ "$remote_name" = "$upstream" ]; then
                    remote_name=$(git remote | awk 'NR == 1 { name = $0 } END { if (NR == 1) print name }')
                fi
            fi
            if [ -n "$remote_name" ] && default_ref=$(git symbolic-ref --quiet --short "refs/remotes/$remote_name/HEAD" 2>/dev/null); then
                echo "default_line=${default_ref#"$remote_name"/}"
            else
                echo 'default_line=unresolved'
            fi
            echo 'staged_changes:'
            if git diff --cached --name-status >"$status_file" && [ -s "$status_file" ]; then
                sed 's/^/  /' "$status_file"
            else
                echo '  (none)'
            fi
            echo 'unstaged_changes:'
            if git diff --name-status >"$status_file" && [ -s "$status_file" ]; then
                sed 's/^/  /' "$status_file"
            else
                echo '  (none)'
            fi
            echo 'untracked_changes:'
            if git ls-files --others --exclude-standard >"$status_file" && [ -s "$status_file" ]; then
                sed 's/^/  /' "$status_file"
            else
                echo '  (none)'
            fi
            ;;
    esac
}

commit_change() {
    message=$1
    selection=$2
    shift 2
    full_message=$(printf '%s\n\n%s' "$message" "$coauthor")

    case $vcs:$selection in
        jj:all)
            jj_snapshot commit -m "$full_message"
            ;;
        jj:paths)
            jj_snapshot commit -m "$full_message" -- "$@"
            ;;
        git:all)
            git add -A
            git commit -m "$full_message"
            ;;
        git:paths)
            git add -- "$@"
            git commit --only -m "$full_message" -- "$@"
            ;;
    esac
}

detect_vcs

case ${1-} in
    snapshot)
        shift
        case ${1-} in
            '') ;;
            --fetch)
                shift
                [ "$#" -le 1 ] || usage
                if fetch_remote "${1-}"; then
                    fetch_status=succeeded
                else
                    fetch_status=failed
                    fetch_result=2
                fi
                ;;
            *) usage ;;
        esac
        snapshot_result=0
        snapshot "${1-}" || snapshot_result=$?
        if [ "$snapshot_result" -ne 0 ]; then
            exit "$snapshot_result"
        fi
        exit "$fetch_result"
        ;;
    commit)
        shift
        [ "${1-}" = '-m' ] || usage
        [ "$#" -ge 3 ] || usage
        message=$2
        [ -n "$message" ] || usage
        shift 2
        case ${1-} in
            --all)
                [ "$#" -eq 1 ] || usage
                commit_change "$message" all
                ;;
            --)
                shift
                [ "$#" -gt 0 ] || usage
                commit_change "$message" paths "$@"
                ;;
            *) usage ;;
        esac
        ;;
    *) usage ;;
esac
