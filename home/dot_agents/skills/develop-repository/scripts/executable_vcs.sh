#!/bin/sh
set -eu

coauthor='Co-authored-by: Codex <codex@openai.com>'

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

fetch_remote() {
    remote=${1-}
    case $vcs in
        jj)
            if [ -n "$remote" ]; then
                jj git fetch --remote "$remote"
            else
                jj git fetch
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
            jj status
            jj log --no-graph -r @ -T '"working_copy=" ++ commit_id ++ " change=" ++ change_id ++ "\n"'
            jj bookmark list --all-remotes
            jj git remote list | awk '{ print $1 }'
            if ! jj log --no-graph -r 'trunk()' -T '"default_line=" ++ commit_id ++ "\n"'; then
                echo 'default_line=unresolved'
            fi
            ;;
        git)
            echo "root=$(git rev-parse --show-toplevel)"
            git status --short --branch
            git remote
            if head=$(git rev-parse --verify HEAD 2>/dev/null); then
                echo "head=$head"
            else
                echo 'head=unborn'
            fi
            if upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
                echo "upstream=$upstream"
            else
                echo 'upstream=unconfigured'
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
            jj commit -m "$full_message"
            ;;
        jj:paths)
            jj commit -m "$full_message" -- "$@"
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
                fetch_remote "${1-}"
                ;;
            *) usage ;;
        esac
        snapshot "${1-}"
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
