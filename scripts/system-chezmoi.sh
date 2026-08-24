#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source_directory="$repository/root"

usage() {
  printf 'usage: %s <diff|apply|verify> [/absolute/file ...]\n' "${0##*/}" >&2
  exit 2
}

if (($# < 1)); then
  usage
fi

operation=$1
shift

case "$operation" in
  diff | apply | verify) ;;
  *) usage ;;
esac

chezmoi_bin="$(command -v chezmoi)"
chezmoi_common_args=(
  --config-format toml
  --config /dev/null
  --source "$source_directory"
  --destination /
  --no-pager
  --no-tty
)

managed_targets="$(
  "$chezmoi_bin" "${chezmoi_common_args[@]}" managed \
    --include=files,symlinks --path-style absolute
)"
managed_symlink_targets="$(
  "$chezmoi_bin" "${chezmoi_common_args[@]}" managed \
    --include=symlinks --path-style absolute
)"

targets=()
declare -A managed_target_set=()
declare -A managed_symlink_target_set=()
if [[ -n $managed_targets ]]; then
  while IFS= read -r target; do
    managed_target_set["$target"]=1
    if (($# == 0)); then
      targets+=("$target")
    fi
  done <<<"$managed_targets"
fi
if [[ -n $managed_symlink_targets ]]; then
  while IFS= read -r target; do
    managed_symlink_target_set["$target"]=1
  done <<<"$managed_symlink_targets"
fi

for target in "$@"; do
  if [[ $target != /* || $target == / || $target == *//* || $target == */../* || $target == */.. || $target == *'/./'* || $target == */. ]]; then
    printf 'system target must be a normalized absolute file path: %s\n' "$target" >&2
    exit 2
  fi
  if [[ ! ${managed_target_set["$target"]+managed} ]]; then
    printf 'system target is not a managed file: %s\n' "$target" >&2
    exit 2
  fi
  targets+=("$target")
done

if ((${#targets[@]} == 0)); then
  printf 'system source contains no managed files: %s\n' "$source_directory" >&2
  exit 2
fi

target_specs=()
for target in "${targets[@]}"; do
  target_type="file"
  if [[ ${managed_symlink_target_set["$target"]+managed} ]]; then
    target_type="symlink"
  fi
  if [[ -d $target && ($target_type != symlink || ! -L $target) ]]; then
    printf 'system target must not be a directory: %s\n' "$target" >&2
    exit 2
  fi
  target_specs+=("$target_type" "$target")
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

chezmoi_args=(
  "${chezmoi_common_args[@]}"
  --persistent-state "$persistent_state"
)

if [[ $operation == diff ]]; then
  chezmoi_args+=(--use-builtin-diff)
fi
chezmoi_args+=("$operation" "${targets[@]}")

if [[ $operation == apply ]]; then
  exec sudo -- sh -c '
    state_directory=$1
    persistent_state=$2
    target_spec_count=$3
    shift 3
    umask 022

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

    while test "$target_spec_count" -ge 2; do
      target_type=$1
      target=$2
      shift 2
      target_spec_count=$((target_spec_count - 2))
      if test -d "$target"; then
        if test "$target_type" != symlink || test ! -L "$target"; then
          printf "system target must not be a directory: %s\n" "$target" >&2
          exit 2
        fi
      fi
      parent=${target%/*}
      if test -z "$parent"; then
        parent=/
      fi
      mkdir -p -- "$parent"
    done
    exec "$@"
  ' system-chezmoi "$root_state_directory" "$persistent_state" \
    "${#target_specs[@]}" "${target_specs[@]}" "$chezmoi_bin" "${chezmoi_args[@]}"
fi
exec "$chezmoi_bin" "${chezmoi_args[@]}"
