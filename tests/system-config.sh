#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

file_mode() {
  if [[ $(uname -s) == Darwin ]]; then
    stat -f %Lp "$1"
  else
    stat -c %a "$1"
  fi
}

udev_source="$repository/root/etc/udev/rules.d/70-atty-usb-serial.rules"
grep -Fxq 'SUBSYSTEM=="tty", KERNEL=="ttyACM[0-9]*|ttyUSB[0-9]*", TAG+="uaccess"' \
  "$udev_source"

destination="$temporary/destination"
mkdir -p "$destination/etc/udev/rules.d"
target="$destination/etc/udev/rules.d/70-atty-usb-serial.rules"
chezmoi_args=(
  --config-format toml
  --config /dev/null
  --source "$repository/root"
  --destination "$destination"
  --persistent-state "$temporary/integration-state.boltdb"
  --no-pager
  --no-tty
)

chezmoi "${chezmoi_args[@]}" apply "$target"
chezmoi "${chezmoi_args[@]}" verify "$target"
test -z "$(chezmoi "${chezmoi_args[@]}" --use-builtin-diff diff "$target")"
cmp "$udev_source" "$target"
test "$(file_mode "$temporary/integration-state.boltdb")" = 600

all_destination="$temporary/all-destination"
mkdir -p "$all_destination"
all_chezmoi_args=(
  --config-format toml
  --config /dev/null
  --source "$repository/root"
  --destination "$all_destination"
  --persistent-state "$temporary/all-integration-state.boltdb"
  --no-pager
  --no-tty
)
all_targets=()
mapfile -t all_targets < <(chezmoi "${all_chezmoi_args[@]}" managed \
  --include=files,symlinks --path-style absolute)
original_umask="$(umask)"
umask 077
(
  umask 022
  for all_target in "${all_targets[@]}"; do
    mkdir -p "${all_target%/*}"
  done
  chezmoi "${all_chezmoi_args[@]}" apply "${all_targets[@]}"
  chezmoi "${all_chezmoi_args[@]}" verify "${all_targets[@]}"
)
umask "$original_umask"
test "$(file_mode "$all_destination/usr/local/share/wayland-sessions")" = 755
test -z "$(chezmoi "${all_chezmoi_args[@]}" --use-builtin-diff diff "${all_targets[@]}")"
while IFS= read -r source_file; do
  destination_file="$all_destination${source_file#"$repository/root"}"
  cmp "$source_file" "$destination_file"
  test "$(file_mode "$destination_file")" = 644
done < <(find "$repository/root" -type f -print)

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
for arg do
  if [ "$arg" = managed ]; then
    case " $* " in
      *' --include=symlinks '*) ;;
      *)
        printf '%s\n' \
          /etc/udev/rules.d/70-atty-usb-serial.rules \
          /usr/local/share/wayland-sessions/scroll-uwsm.desktop
        if [ -n "${FAKE_MANAGED_FILE_TARGET:-}" ]; then
          printf '%s\n' "$FAKE_MANAGED_FILE_TARGET"
        fi
        ;;
    esac
    if [ -n "${FAKE_MANAGED_SYMLINK_TARGET:-}" ]; then
      printf '%s\n' "$FAKE_MANAGED_SYMLINK_TARGET"
    fi
    exit 0
  fi
done
EOF
cat >"$fake_bin/sudo" <<'EOF'
#!/bin/sh
test "$1" = --
shift
printf '%s\n' "$@" >>"$FAKE_SUDO_LOG"
if [ "$1" = sh ] && [ "$2" = -c ]; then
  shift 6
  target_spec_count=$1
  shift
  while [ "$target_spec_count" -ge 2 ]; do
    target_type=$1
    target=$2
    shift 2
    target_spec_count=$((target_spec_count - 2))
    if [ -n "${FAKE_ROOT_DIRECTORY:-}" ] && [ "$target" = "$FAKE_ROOT_DIRECTORY" ]; then
      printf 'system target must not be a directory: %s\n' "$target" >&2
      exit 2
    fi
  done
  exec "$@"
fi
exec "$@"
EOF
chmod +x "$fake_bin/chezmoi" "$fake_bin/sudo"

run_system() {
  PATH="$fake_bin:/usr/bin:/bin" XDG_CACHE_HOME="$temporary/cache" \
    FAKE_CHEZMOI_LOG="$temporary/invocation" \
    FAKE_SUDO_LOG="$temporary/sudo-invocations" \
    FAKE_ROOT_DIRECTORY="${FAKE_ROOT_DIRECTORY:-}" \
    FAKE_MANAGED_FILE_TARGET="${FAKE_MANAGED_FILE_TARGET:-}" \
    FAKE_MANAGED_SYMLINK_TARGET="${FAKE_MANAGED_SYMLINK_TARGET:-}" \
    bash "$repository/scripts/system-chezmoi.sh" "$@"
}

run_system diff /etc/udev/rules.d/70-atty-usb-serial.rules
grep -Fxq -- '--source' "$temporary/invocation"
grep -Fxq "$repository/root" "$temporary/invocation"
grep -Fxq -- '--destination' "$temporary/invocation"
grep -Fxq / "$temporary/invocation"
grep -Fxq -- '--persistent-state' "$temporary/invocation"
grep -Fxq "$temporary/cache/chezmoi-system/chezmoistate.boltdb" "$temporary/invocation"
grep -Fxq -- '--use-builtin-diff' "$temporary/invocation"
grep -Fxq diff "$temporary/invocation"
grep -Fxq /etc/udev/rules.d/70-atty-usb-serial.rules "$temporary/invocation"
test "$(file_mode "$temporary/cache/chezmoi-system")" = 700

rm -f "$temporary/sudo-invocations"
run_system apply /etc/udev/rules.d/70-atty-usb-serial.rules
grep -Fxq apply "$temporary/invocation"
grep -Fxq /root/.cache/chezmoi-system/chezmoistate.boltdb "$temporary/invocation"
grep -Fq 'stat -c %u:%g' "$temporary/sudo-invocations"
grep -Fq 'umask 022' "$temporary/sudo-invocations"
grep -Fq "mkdir -p -- \"\$parent\"" "$temporary/sudo-invocations"
grep -Fxq /root/.cache/chezmoi-system "$temporary/sudo-invocations"
run_system verify /etc/udev/rules.d/70-atty-usb-serial.rules
grep -Fxq verify "$temporary/invocation"

run_system diff
grep -Fxq /etc/udev/rules.d/70-atty-usb-serial.rules "$temporary/invocation"
grep -Fxq /usr/local/share/wayland-sessions/scroll-uwsm.desktop "$temporary/invocation"
run_system apply
grep -Fxq /etc/udev/rules.d/70-atty-usb-serial.rules "$temporary/invocation"
grep -Fxq /usr/local/share/wayland-sessions/scroll-uwsm.desktop "$temporary/invocation"
run_system verify
grep -Fxq /etc/udev/rules.d/70-atty-usb-serial.rules "$temporary/invocation"
grep -Fxq /usr/local/share/wayland-sessions/scroll-uwsm.desktop "$temporary/invocation"

fake_symlink_directory="$temporary/fake-symlink-directory"
fake_symlink_target="$temporary/fake-symlink-target"
mkdir -p "$fake_symlink_directory"
ln -s "$fake_symlink_directory" "$fake_symlink_target"
FAKE_MANAGED_SYMLINK_TARGET="$fake_symlink_target" run_system apply
grep -Fxq symlink "$temporary/sudo-invocations"
grep -Fxq "$fake_symlink_target" "$temporary/sudo-invocations"

if FAKE_MANAGED_FILE_TARGET="$fake_symlink_target" \
  run_system apply "$fake_symlink_target" >"$temporary/rejected" 2>&1; then
  printf 'system apply accepted a directory symlink for a managed file\n' >&2
  exit 1
fi
grep -Fxq "system target must not be a directory: $fake_symlink_target" \
  "$temporary/rejected"

rm -f "$temporary/invocation" "$temporary/sudo-invocations"
PATH="$fake_bin:/usr/bin:/bin" XDG_CACHE_HOME=/proc/chezmoi-system-review \
  FAKE_CHEZMOI_LOG="$temporary/invocation" FAKE_SUDO_LOG="$temporary/sudo-invocations" \
  bash "$repository/scripts/system-chezmoi.sh" apply \
    /etc/udev/rules.d/70-atty-usb-serial.rules
grep -Fxq apply "$temporary/invocation"

rm -f "$temporary/invocation"
if FAKE_ROOT_DIRECTORY=/etc/udev/rules.d/70-atty-usb-serial.rules \
  run_system apply /etc/udev/rules.d/70-atty-usb-serial.rules >"$temporary/rejected" 2>&1; then
  printf 'system apply accepted a directory visible only to root\n' >&2
  exit 1
fi
grep -Fxq 'system target must not be a directory: /etc/udev/rules.d/70-atty-usb-serial.rules' \
  "$temporary/rejected"
grep -Fxq managed "$temporary/invocation"
if grep -Fxq apply "$temporary/invocation"; then
  printf 'system apply reached chezmoi after the root-only directory rejection\n' >&2
  exit 1
fi

live_directory="$temporary/live-directory"
mkdir -p "$live_directory"
touch "$live_directory/keep"
live_directory_link="$temporary/live-directory-link"
ln -s "$live_directory" "$live_directory_link"
for collision in "$live_directory" "$live_directory_link"; do
  for operation in diff apply verify; do
    rm -f "$temporary/invocation"
    if FAKE_MANAGED_FILE_TARGET="$collision" \
      run_system "$operation" "$collision" >"$temporary/rejected" 2>&1; then
      printf 'system %s accepted a destination directory: %s\n' "$operation" "$collision" >&2
      exit 1
    fi
    grep -Fxq "system target must not be a directory: $collision" "$temporary/rejected"
    grep -Fxq managed "$temporary/invocation"
    if grep -Fxq "$operation" "$temporary/invocation"; then
      printf 'system %s reached chezmoi after a directory rejection: %s\n' \
        "$operation" "$collision" >&2
      exit 1
    fi
    test -f "$live_directory/keep"
  done
done

for invalid in etc/udev/rules.d/70-atty-usb-serial.rules / /etc /etc/../etc/passwd; do
  if run_system verify "$invalid" >"$temporary/rejected" 2>&1; then
    printf 'unsafe system target was accepted: %s\n' "$invalid" >&2
    exit 1
  fi
done

if PATH="$fake_bin:/usr/bin:/bin" FAKE_CHEZMOI_LOG="$temporary/invocation" \
  bash "$repository/scripts/system-chezmoi.sh" >"$temporary/rejected" 2>&1; then
  printf 'system command accepted a missing operation\n' >&2
  exit 1
fi

if command -v udevadm >/dev/null && udevadm verify --help >/dev/null 2>&1; then
  test -z "$(udevadm verify --no-summary "$target" 2>&1)"
fi
