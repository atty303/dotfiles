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

chezmoi_bin="$(command -v chezmoi)"
chezmoi_args=(
  --config-format toml
  --config /dev/null
  --source "$source_directory"
  --destination /
  --no-pager
  --no-tty
)

if [[ $operation == diff ]]; then
  chezmoi_args+=(--use-builtin-diff)
fi
chezmoi_args+=("$operation" "${targets[@]}")

if [[ $operation == apply ]]; then
  sudo -- sh -c '
    for target do
      if test -d "$target"; then
        printf "system target must not be a directory: %s\n" "$target" >&2
        exit 2
      fi
    done
  ' system-chezmoi "${targets[@]}"
  exec sudo -- "$chezmoi_bin" "${chezmoi_args[@]}"
fi
exec "$chezmoi_bin" "${chezmoi_args[@]}"
