#!/bin/sh
set -eu

usage() {
    cat >&2 <<'EOF'
usage:
  vcs-push.sh REMOTE BRANCH_OR_BOOKMARK
  vcs-push.sh REMOTE --change REVISION
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
            jj git push --remote "$remote" --change "$2"
            ;;
        *)
            [ "$#" -eq 1 ] || usage
            jj git push --remote "$remote" --bookmark "$1"
            ;;
    esac
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
    [ "$#" -eq 1 ] || usage
    git push "$remote" "$1"
else
    echo 'not inside a jj or Git repository' >&2
    exit 1
fi
