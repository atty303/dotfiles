#!/bin/sh
set -eu

usage() {
    cat >&2 <<'EOF'
usage:
  vcs-push.sh REMOTE BRANCH_OR_BOOKMARK
  vcs-push.sh REMOTE --change REVISION
  vcs-push.sh REMOTE --notes
EOF
    exit 64
}

[ "$#" -eq 2 ] || [ "$#" -eq 3 ] || usage
remote=$1
shift

if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
    case $1 in
        --change)
            [ "$#" -eq 2 ] || usage
            jj --config snapshot.auto-update-stale=false git push --remote "$remote" --change "$2"
            ;;
        --notes)
            [ "$#" -eq 1 ] || usage
            command -v git >/dev/null 2>&1 || {
                echo 'Git notes operations require the system git executable' >&2
                exit 127
            }
            git --git-dir="$(jj --config snapshot.auto-update-stale=false git root)" push "$remote" refs/notes/commits:refs/notes/commits
            ;;
        *)
            [ "$#" -eq 1 ] || usage
            jj --config snapshot.auto-update-stale=false git push --remote "$remote" --bookmark "$1"
            ;;
    esac
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    [ "$#" -eq 1 ] || usage
    case $1 in
        --notes)
            git push "$remote" refs/notes/commits:refs/notes/commits
            ;;
        *)
            git push "$remote" "$1"
            ;;
    esac
else
    echo 'not inside a jj or Git repository' >&2
    exit 1
fi
