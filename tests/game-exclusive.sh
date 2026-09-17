#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
partition_helper="$repository/root/usr/local/libexec/executable_game-exclusive-partition"
launcher="$repository/home/dot_local/bin/executable_game-exclusive"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

make_fake_partition() {
  partition=$1
  state=$2
  populated=$3
  effective=$4
  exclusive=$5
  mkdir -p "$partition"
  printf 'populated %s\nfrozen 0\n' "$populated" >"$partition/cgroup.events"
  printf '%s\n' "$state" >"$partition/cpuset.cpus.partition"
  printf '%s\n' "$effective" >"$partition/cpuset.cpus.effective"
  printf '%s' "$exclusive" >"$partition/cpuset.cpus.exclusive"
  ln -sfn cpuset.cpus.exclusive "$partition/cpuset.cpus.exclusive.effective"
}

fake_root="$temporary/cgroup"
fake_partition="$fake_root/game.slice"
make_fake_partition "$fake_partition" member 0 0-7,12-19 ''

GAME_EXCLUSIVE_CGROUP_ROOT="$fake_root" sh "$partition_helper" activate \
  >"$temporary/activate"
grep -Fxq 'game-exclusive-partition status=active cpus=0-7,12-19 changed=true' \
  "$temporary/activate"
test "$(cat "$fake_partition/cpuset.cpus.partition")" = root
test "$(cat "$fake_partition/cpuset.cpus.exclusive")" = 0-7,12-19

GAME_EXCLUSIVE_CGROUP_ROOT="$fake_root" sh "$partition_helper" check \
  >"$temporary/check"
grep -Fxq 'game-exclusive-partition status=active cpus=0-7,12-19' "$temporary/check"

printf 'populated 1\nfrozen 0\n' >"$fake_partition/cgroup.events"
if GAME_EXCLUSIVE_CGROUP_ROOT="$fake_root" sh "$partition_helper" deactivate \
  >"$temporary/busy-output" 2>"$temporary/busy-error"; then
  printf 'partition helper deactivated a populated partition\n' >&2
  exit 1
fi
grep -Fq 'error=partition_busy' "$temporary/busy-error"
test "$(cat "$fake_partition/cpuset.cpus.partition")" = root

printf 'populated 0\nfrozen 0\n' >"$fake_partition/cgroup.events"
GAME_EXCLUSIVE_CGROUP_ROOT="$fake_root" sh "$partition_helper" deactivate \
  >"$temporary/deactivate"
grep -Fxq 'game-exclusive-partition status=inactive changed=true' \
  "$temporary/deactivate"
test "$(cat "$fake_partition/cpuset.cpus.partition")" = member
test ! -s "$fake_partition/cpuset.cpus.exclusive"

rollback_root="$temporary/rollback-cgroup"
rollback_partition="$rollback_root/game.slice"
mkdir -p "$rollback_partition"
printf 'populated 0\nfrozen 0\n' >"$rollback_partition/cgroup.events"
printf 'member\n' >"$rollback_partition/cpuset.cpus.partition"
printf '0-7,12-19\n' >"$rollback_partition/cpuset.cpus.effective"
: >"$rollback_partition/cpuset.cpus.exclusive"
: >"$rollback_partition/cpuset.cpus.exclusive.effective"
if GAME_EXCLUSIVE_CGROUP_ROOT="$rollback_root" sh "$partition_helper" activate \
  >"$temporary/rollback-output" 2>"$temporary/rollback-error"; then
  printf 'partition helper accepted a failed activation verification\n' >&2
  exit 1
fi
grep -Fq 'error=partition_verification_failed' "$temporary/rollback-error"
test "$(cat "$rollback_partition/cpuset.cpus.partition")" = member
test ! -s "$rollback_partition/cpuset.cpus.exclusive"

fake_systemd_run="$temporary/systemd-run"
cat >"$fake_systemd_run" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$GAME_EXCLUSIVE_ARGUMENT_LOG"
EOF
chmod +x "$fake_systemd_run"

make_fake_partition "$fake_partition" root 0 0-7,12-19 0-7,12-19
GAME_EXCLUSIVE_CGROUP_ROOT="$fake_root" \
  GAME_EXCLUSIVE_SYSTEMD_RUN="$fake_systemd_run" \
  GAME_EXCLUSIVE_ARGUMENT_LOG="$temporary/arguments" \
  sh "$launcher" -- /usr/bin/printf '%s %s' hello world
cat >"$temporary/expected-arguments" <<'EOF'
--system
--scope
--quiet
--collect
--unit=game-exclusive.scope
--slice=game.slice
--
/usr/bin/printf
%s %s
hello
world
EOF
cmp "$temporary/expected-arguments" "$temporary/arguments"

printf 'member\n' >"$fake_partition/cpuset.cpus.partition"
if GAME_EXCLUSIVE_CGROUP_ROOT="$fake_root" \
  GAME_EXCLUSIVE_SYSTEMD_RUN="$fake_systemd_run" \
  sh "$launcher" true >"$temporary/invalid-output" 2>"$temporary/invalid-error"; then
  printf 'game launcher accepted an inactive partition\n' >&2
  exit 1
fi
grep -Fq 'error=partition_state_invalid' "$temporary/invalid-error"

infinitas_destination="$temporary/infinitas-destination"
mkdir -p "$infinitas_destination"
infinitas_args=(
  --config-format toml
  --config /dev/null
  --source "$repository/root"
  --destination "$infinitas_destination"
  --persistent-state "$temporary/infinitas-state.boltdb"
  --override-data '{"chezmoi":{"hostname":"infinitas"}}'
  --no-pager
  --no-tty
)
mapfile -t infinitas_targets < <(
  chezmoi "${infinitas_args[@]}" managed --include=files,symlinks --path-style absolute
)
for target in "${infinitas_targets[@]}"; do
  mkdir -p "${target%/*}"
done
chezmoi "${infinitas_args[@]}" apply "${infinitas_targets[@]}"
chezmoi "${infinitas_args[@]}" verify "${infinitas_targets[@]}"
test -x "$infinitas_destination/usr/local/libexec/game-exclusive-partition"
test -L \
  "$infinitas_destination/etc/systemd/system/multi-user.target.wants/game-exclusive-partition.service"
test "$(readlink "$infinitas_destination/etc/systemd/system/multi-user.target.wants/game-exclusive-partition.service")" = \
  /etc/systemd/system/game-exclusive-partition.service

other_destination="$temporary/other-destination"
mkdir -p "$other_destination"
if chezmoi --config-format toml --config /dev/null --source "$repository/root" \
  --destination "$other_destination" --persistent-state "$temporary/other-state.boltdb" \
  --override-data '{"chezmoi":{"hostname":"other"}}' --no-pager --no-tty \
  managed --include=files,symlinks --path-style absolute |
  grep -Fq game-exclusive; then
  printf 'host-specific game partition files rendered for another host\n' >&2
  exit 1
fi
