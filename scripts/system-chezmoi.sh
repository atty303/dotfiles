#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_directory="$repository/root"

usage() {
  printf 'usage: %s <diff|apply|verify> /absolute/file [...]\n' "${0##*/}" >&2
  exit 2
}

if (($# < 2)); then
  usage
fi

operation=$1
shift

case "$operation" in
  diff | apply | verify) ;;
  *) usage ;;
esac

targets=()
for target in "$@"; do
  if [[ $target != /* || $target == / || $target == *//* || $target == */../* || $target == */.. || $target == *'/./'* || $target == */. ]]; then
    printf 'system target must be a normalized absolute file path: %s\n' "$target" >&2
    exit 2
  fi
  if [[ -d $target ]]; then
    printf 'system target must not be a directory: %s\n' "$target" >&2
    exit 2
  fi

  source_path="$source_directory$target"
  if [[ ! -f $source_path && ! -L $source_path ]]; then
    printf 'system target is not a managed file: %s\n' "$target" >&2
    exit 2
  fi
  targets+=("$target")
done

if [[ $operation == apply ]]; then
  root_state_directory=/root/.cache/chezmoi-system
  persistent_state="$root_state_directory/chezmoistate.boltdb"
else
  state_directory="${XDG_CACHE_HOME:-$HOME/.cache}/chezmoi-system"
  mkdir -p "$state_directory"
  chmod 0700 "$state_directory"
  persistent_state="$state_directory/chezmoistate.boltdb"
fi

chezmoi_bin="$(command -v chezmoi)"
chezmoi_args=(
  --config-format toml
  --config /dev/null
  --source "$source_directory"
  --destination /
  --persistent-state "$persistent_state"
  --no-pager
  --no-tty
)

if [[ $operation == diff ]]; then
  chezmoi_args+=(--use-builtin-diff)
fi
chezmoi_args+=("$operation" "${targets[@]}")

if [[ $operation == apply ]]; then
  sudo -- sh -c '
    state_directory=$1
    persistent_state=$2
    shift 2

    if test -L "$state_directory"; then
      printf "system state directory must not be a symlink: %s\n" "$state_directory" >&2
      exit 2
    fi
    mkdir -p "$state_directory"
    if test ! -d "$state_directory" || test -L "$state_directory" || \
      test "$(stat -c %u:%g "$state_directory")" != 0:0; then
      printf "system state directory must be owned by root: %s\n" "$state_directory" >&2
      exit 2
    fi
    chmod 0700 "$state_directory"

    if test -e "$persistent_state" || test -L "$persistent_state"; then
      if test ! -f "$persistent_state" || test -L "$persistent_state" || \
        test "$(stat -c %u:%g "$persistent_state")" != 0:0; then
        printf "system persistent state must be a root-owned regular file: %s\n" \
          "$persistent_state" >&2
        exit 2
      fi
      chmod 0600 "$persistent_state"
    fi

    for target do
      if test -d "$target"; then
        printf "system target must not be a directory: %s\n" "$target" >&2
        exit 2
      fi
    done
  ' system-chezmoi "$root_state_directory" "$persistent_state" "${targets[@]}"
  exec sudo -- "$chezmoi_bin" "${chezmoi_args[@]}"
fi
exec "$chezmoi_bin" "${chezmoi_args[@]}"
