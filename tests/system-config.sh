#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

sysusers_source="$repository/root/etc/sysusers.d/90-atty-dialout.conf"
grep -Fxq 'm atty dialout' "$sysusers_source"

destination="$temporary/destination"
mkdir -p "$destination/etc/sysusers.d"
target="$destination/etc/sysusers.d/90-atty-dialout.conf"
chezmoi_args=(
  --config-format toml
  --config /dev/null
  --source "$repository/root"
  --destination "$destination"
  --no-pager
  --no-tty
)

chezmoi "${chezmoi_args[@]}" apply "$target"
chezmoi "${chezmoi_args[@]}" verify "$target"
test -z "$(chezmoi "${chezmoi_args[@]}" --use-builtin-diff diff "$target")"
cmp "$sysusers_source" "$target"

printf '# drift\n' >>"$target"
if chezmoi "${chezmoi_args[@]}" verify "$target"; then
  printf 'system verify accepted a modified target\n' >&2
  exit 1
fi
test -n "$(chezmoi "${chezmoi_args[@]}" --use-builtin-diff diff "$target")"

fake_bin="$temporary/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/chezmoi" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$FAKE_CHEZMOI_LOG"
EOF
cat >"$fake_bin/sudo" <<'EOF'
#!/bin/sh
test "$1" = --
shift
if [ "$1" = sh ] && [ "$2" = -c ] && [ -n "${FAKE_ROOT_DIRECTORY:-}" ]; then
  shift 3
  for target do
    if [ "$target" = "$FAKE_ROOT_DIRECTORY" ]; then
      printf 'system target must not be a directory: %s\n' "$target" >&2
      exit 2
    fi
  done
  exit 0
fi
exec "$@"
EOF
chmod +x "$fake_bin/chezmoi" "$fake_bin/sudo"

run_system() {
  PATH="$fake_bin:/usr/bin:/bin" FAKE_CHEZMOI_LOG="$temporary/invocation" \
    FAKE_ROOT_DIRECTORY="${FAKE_ROOT_DIRECTORY:-}" \
    bash "$repository/scripts/system-chezmoi.sh" "$@"
}

run_system diff /etc/sysusers.d/90-atty-dialout.conf
grep -Fxq -- '--source' "$temporary/invocation"
grep -Fxq "$repository/root" "$temporary/invocation"
grep -Fxq -- '--destination' "$temporary/invocation"
grep -Fxq / "$temporary/invocation"
grep -Fxq -- '--use-builtin-diff' "$temporary/invocation"
grep -Fxq diff "$temporary/invocation"
grep -Fxq /etc/sysusers.d/90-atty-dialout.conf "$temporary/invocation"

run_system apply /etc/sysusers.d/90-atty-dialout.conf
grep -Fxq apply "$temporary/invocation"
run_system verify /etc/sysusers.d/90-atty-dialout.conf
grep -Fxq verify "$temporary/invocation"

rm -f "$temporary/invocation"
if FAKE_ROOT_DIRECTORY=/etc/sysusers.d/90-atty-dialout.conf \
  run_system apply /etc/sysusers.d/90-atty-dialout.conf >"$temporary/rejected" 2>&1; then
  printf 'system apply accepted a directory visible only to root\n' >&2
  exit 1
fi
grep -Fxq 'system target must not be a directory: /etc/sysusers.d/90-atty-dialout.conf' \
  "$temporary/rejected"
test ! -e "$temporary/invocation"

live_directory="$temporary/live-directory"
mkdir -p "$live_directory"
touch "$live_directory/keep"
live_directory_link="$temporary/live-directory-link"
ln -s "$live_directory" "$live_directory_link"
for collision in "$live_directory" "$live_directory_link"; do
  for operation in diff apply verify; do
    rm -f "$temporary/invocation"
    if run_system "$operation" "$collision" >"$temporary/rejected" 2>&1; then
      printf 'system %s accepted a destination directory: %s\n' "$operation" "$collision" >&2
      exit 1
    fi
    grep -Fxq "system target must not be a directory: $collision" "$temporary/rejected"
    test ! -e "$temporary/invocation"
    test -f "$live_directory/keep"
  done
done

for invalid in etc/sysusers.d/90-atty-dialout.conf / /etc /etc/../etc/passwd; do
  if run_system verify "$invalid" >"$temporary/rejected" 2>&1; then
    printf 'unsafe system target was accepted: %s\n' "$invalid" >&2
    exit 1
  fi
done

if PATH="$fake_bin:/usr/bin:/bin" FAKE_CHEZMOI_LOG="$temporary/invocation" \
  bash "$repository/scripts/system-chezmoi.sh" verify >"$temporary/rejected" 2>&1; then
  printf 'system command accepted an empty target list\n' >&2
  exit 1
fi

if command -v systemd-sysusers >/dev/null; then
  systemd-sysusers --dry-run --root="$destination" >/dev/null 2>&1
fi
