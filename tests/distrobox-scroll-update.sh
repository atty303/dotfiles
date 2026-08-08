#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
helper="$repository/home/dot_local/libexec/executable_chezmoi-distrobox-scroll-update"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export FAKE_CONTAINER_DIR="$test_root/containers"
export PATH="$test_root/bin:$PATH"

mkdir -p "$test_root/bin" "$FAKE_CONTAINER_DIR" "$HOME/.local/bin" \
  "$XDG_CONFIG_HOME/distrobox/assemble"
: >"$XDG_CONFIG_HOME/distrobox/assemble/scroll.ini"

cat >"$test_root/bin/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  "container exists")
    if [[ "${FAKE_PODMAN_EXISTS_ERROR:-}" == "$3" ]]; then
      exit 125
    fi
    [[ -e "$FAKE_CONTAINER_DIR/$3" ]]
    ;;
  "stop --ignore")
    [[ "${FAKE_PODMAN_FAIL_STOP:-0}" != 1 ]]
    ;;
  "rename "*)
    [[ "${FAKE_PODMAN_FAIL_RENAME:-0}" != 1 ]]
    mv "$FAKE_CONTAINER_DIR/$2" "$FAKE_CONTAINER_DIR/$3"
    ;;
  "rm --force")
    [[ "${FAKE_PODMAN_FAIL_RM:-0}" != 1 ]]
    rm -f "$FAKE_CONTAINER_DIR/$3"
    ;;
  *)
    printf 'unexpected podman arguments: %q ' "$@" >&2
    printf '\n' >&2
    exit 2
    ;;
esac
EOF
chmod +x "$test_root/bin/podman"

cat >"$test_root/bin/distrobox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-} ${2:-}" in
  "assemble create")
    printf 'new-container\n' >"$FAKE_CONTAINER_DIR/scroll"
    for wrapper in scroll scrollmsg scrollnag scrollbar; do
      printf 'new-%s\n' "$wrapper" >"$HOME/.local/bin/$wrapper"
    done
    if [[ "${FAKE_DISTROBOX_FAIL_CREATE:-0}" == 1 ]]; then
      exit 42
    fi
    ;;
  "rm --force")
    rm -f "$FAKE_CONTAINER_DIR/$3"
    for wrapper in scroll scrollmsg scrollnag scrollbar; do
      rm -f "$HOME/.local/bin/$wrapper"
    done
    ;;
  *)
    printf 'unexpected distrobox arguments: %q ' "$@" >&2
    printf '\n' >&2
    exit 2
    ;;
esac
EOF
chmod +x "$test_root/bin/distrobox"

cat >"$test_root/bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-} ${2:-}" == "--user show" ]]; then
  printf '%s\n' "${FAKE_SYSTEMD_STATE:-inactive}"
else
  printf 'unexpected systemctl arguments: %q ' "$@" >&2
  printf '\n' >&2
  exit 2
fi
EOF
chmod +x "$test_root/bin/systemctl"

state_dir="$XDG_STATE_HOME/chezmoi/distrobox"
wrappers=(scroll scrollmsg scrollnag scrollbar)

reset_old_container() {
  local wrapper

  rm -rf "$state_dir"
  rm -f "$FAKE_CONTAINER_DIR/scroll" "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"
  printf 'old-container\n' >"$FAKE_CONTAINER_DIR/scroll"
  for wrapper in "${wrappers[@]}"; do
    printf 'old-%s\n' "$wrapper" >"$HOME/.local/bin/$wrapper"
  done
  mkdir -p "$state_dir"
}

assert_file_value() {
  local path="${1:?path is required}"
  local expected="${2:?expected is required}"
  local actual

  [[ -f "$path" ]] || { printf 'missing file: %s\n' "$path" >&2; exit 1; }
  actual="$(<"$path")"
  [[ "$actual" == "$expected" ]] || {
    printf 'unexpected value for %s: expected %q, got %q\n' "$path" "$expected" "$actual" >&2
    exit 1
  }
}

assert_missing() {
  [[ ! -e "${1:?path is required}" ]] || { printf 'unexpected path: %s\n' "$1" >&2; exit 1; }
}

seed_wrapper_backup() {
  local wrapper

  rm -rf "$state_dir/scroll-wrappers"
  mkdir -p "$state_dir/scroll-wrappers"
  for wrapper in "${wrappers[@]}"; do
    cp -a "$HOME/.local/bin/$wrapper" "$state_dir/scroll-wrappers/"
  done
}

write_transaction() {
  local phase="${1:?phase is required}"
  local desired="${2:?desired is required}"
  local had_old="${3:?had_old is required}"

  printf '%s\n%s\n%s\n' "$phase" "$desired" "$had_old" >"$state_dir/scroll.transaction"
}

reset_old_container
printf 'digest-1\n' >"$state_dir/scroll.pending"
bash "$helper" prepare
assert_file_value "$FAKE_CONTAINER_DIR/scroll" new-container
assert_file_value "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback" old-container
assert_file_value "$state_dir/scroll.transaction" $'prepared\ndigest-1\nyes'
assert_file_value "$state_dir/scroll-wrappers/scroll" old-scroll

export FAKE_SYSTEMD_STATE=active
bash "$helper" reconcile
unset FAKE_SYSTEMD_STATE
assert_file_value "$state_dir/scroll.applied" digest-1
assert_missing "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"
assert_missing "$state_dir/scroll.transaction"

reset_old_container
printf 'old-digest\n' >"$state_dir/scroll.applied"
printf 'digest-2\n' >"$state_dir/scroll.pending"
export FAKE_DISTROBOX_FAIL_CREATE=1
if bash "$helper" prepare; then
  printf 'prepare unexpectedly succeeded\n' >&2
  exit 1
fi
unset FAKE_DISTROBOX_FAIL_CREATE
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$HOME/.local/bin/scroll" old-scroll
assert_file_value "$state_dir/scroll.failed" digest-2
assert_file_value "$state_dir/scroll.applied" old-digest
assert_missing "$state_dir/scroll.pending"

printf 'digest-2\n' >"$state_dir/scroll.pending"
bash "$helper" prepare
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_missing "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"

rm -f "$state_dir/scroll.failed"
bash "$helper" prepare
assert_file_value "$FAKE_CONTAINER_DIR/scroll" new-container
export FAKE_SYSTEMD_STATE=failed
bash "$helper" reconcile
unset FAKE_SYSTEMD_STATE
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$HOME/.local/bin/scrollbar" old-scrollbar
assert_file_value "$state_dir/scroll.failed" digest-2
assert_missing "$state_dir/scroll.transaction"

# Podman backend errors are not treated as container absence.
reset_old_container
export FAKE_PODMAN_EXISTS_ERROR=scroll
if bash "$helper" apply digest-query-error; then
  printf 'apply unexpectedly ignored a Podman query error\n' >&2
  exit 1
fi
unset FAKE_PODMAN_EXISTS_ERROR
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$HOME/.local/bin/scroll" old-scroll
assert_missing "$state_dir/scroll.transaction"

# A failure before rename leaves the old container intact and records a failed update.
reset_old_container
printf 'digest-3\n' >"$state_dir/scroll.pending"
export FAKE_PODMAN_FAIL_STOP=1
if bash "$helper" prepare; then
  printf 'prepare unexpectedly survived a stop failure\n' >&2
  exit 1
fi
unset FAKE_PODMAN_FAIL_STOP
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$state_dir/scroll.failed" digest-3
assert_missing "$state_dir/scroll.transaction"

# A corrupt pending state is rejected before wrappers or containers are touched.
reset_old_container
: >"$state_dir/scroll.pending"
if bash "$helper" prepare; then
  printf 'prepare unexpectedly accepted an empty digest\n' >&2
  exit 1
fi
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$HOME/.local/bin/scroll" old-scroll
assert_missing "$state_dir/scroll.transaction"

# Recovery distinguishes a crash before rename from one immediately after rename.
reset_old_container
seed_wrapper_backup
write_transaction backup-ready digest-4 yes
bash "$helper" recover
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$state_dir/scroll.failed" digest-4

reset_old_container
seed_wrapper_backup
write_transaction backup-ready digest-5 yes
mv "$FAKE_CONTAINER_DIR/scroll" "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"
bash "$helper" recover
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$state_dir/scroll.failed" digest-5
assert_missing "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"

# Every durable rollback phase resumes after a hard stop.
reset_old_container
seed_wrapper_backup
mv "$FAKE_CONTAINER_DIR/scroll" "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"
printf 'new-container\n' >"$FAKE_CONTAINER_DIR/scroll"
write_transaction rollback-started digest-5a yes
bash "$helper" recover
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$state_dir/scroll.failed" digest-5a

reset_old_container
seed_wrapper_backup
mv "$FAKE_CONTAINER_DIR/scroll" "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"
write_transaction rollback-candidate-removed digest-5b yes
bash "$helper" recover
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$state_dir/scroll.failed" digest-5b

# A stop immediately after the reverse rename is detected from container names.
reset_old_container
seed_wrapper_backup
write_transaction rollback-candidate-removed digest-5c yes
bash "$helper" recover
assert_file_value "$FAKE_CONTAINER_DIR/scroll" old-container
assert_file_value "$state_dir/scroll.failed" digest-5c

# Wrapper restoration is idempotent after a stop at every wrapper boundary.
for restored_count in 0 1 2 3 4; do
  reset_old_container
  seed_wrapper_backup
  for wrapper in "${wrappers[@]}"; do
    printf 'new-%s\n' "$wrapper" >"$HOME/.local/bin/$wrapper"
  done
  for ((index = 0; index < restored_count; index++)); do
    wrapper="${wrappers[index]}"
    cp -a "$state_dir/scroll-wrappers/$wrapper" "$HOME/.local/bin/$wrapper"
  done
  write_transaction rollback-container-restored "digest-5d-${restored_count}" yes
  bash "$helper" recover
  for wrapper in "${wrappers[@]}"; do
    assert_file_value "$HOME/.local/bin/$wrapper" "old-${wrapper}"
  done
done

# Transaction cleanup resumes after the durable wrapper-restored phase.
reset_old_container
seed_wrapper_backup
printf 'digest-5e\n' >"$state_dir/scroll.pending"
write_transaction rollback-wrappers-restored digest-5e yes
rm -rf "$state_dir/scroll-wrappers"
bash "$helper" recover
assert_file_value "$state_dir/scroll.failed" digest-5e
assert_missing "$state_dir/scroll.transaction"
assert_missing "$state_dir/scroll.pending"

# Once readiness is published, interrupted cleanup is resumed and never rolled back.
reset_old_container
printf 'digest-6\n' >"$state_dir/scroll.pending"
bash "$helper" prepare
write_transaction committed digest-6 yes
rm -f "$FAKE_CONTAINER_DIR/scroll-chezmoi-rollback"
bash "$helper" recover
assert_file_value "$FAKE_CONTAINER_DIR/scroll" new-container
assert_file_value "$state_dir/scroll.applied" digest-6
assert_missing "$state_dir/scroll.transaction"

# A cleanup failure after readiness remains committed and is retried without rollback.
reset_old_container
printf 'digest-7\n' >"$state_dir/scroll.pending"
bash "$helper" prepare
export FAKE_PODMAN_FAIL_RM=1
if bash "$helper" commit; then
  printf 'commit unexpectedly survived a cleanup failure\n' >&2
  exit 1
fi
unset FAKE_PODMAN_FAIL_RM
assert_file_value "$FAKE_CONTAINER_DIR/scroll" new-container
assert_file_value "$state_dir/scroll.transaction" $'committed\ndigest-7\nyes'
bash "$helper" rollback
assert_file_value "$FAKE_CONTAINER_DIR/scroll" new-container
assert_file_value "$state_dir/scroll.applied" digest-7
assert_missing "$state_dir/scroll.transaction"

# The persistent lock inode is harmless after its owning process exits.
printf 'digest-8\n' >"$state_dir/scroll.pending"
bash "$helper" prepare
assert_file_value "$state_dir/scroll.transaction" $'prepared\ndigest-8\nyes'
bash "$helper" rollback

printf 'distrobox Scroll update tests passed\n'
