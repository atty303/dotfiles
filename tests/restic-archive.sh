#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
export RESTIC_CACHE_DIR="$temporary/restic-cache"
mkdir -p "$RESTIC_CACHE_DIR"

test_home="$temporary/home"
config_dir="$test_home/.config/restic"
state_dir="$test_home/.local/state/restic-archive"
mkdir -p \
  "$test_home/.local/bin" \
  "$config_dir" \
  "$temporary/source/cache"

data=$(printf '{"roles":["secrets"],"chezmoi":{"hostname":"cristina","os":"linux","homeDir":"%s"}}' \
  "$test_home")
chezmoi execute-template --source "$repository" --override-data "$data" \
  <"$repository/home/dot_local/bin/executable_restic-archive.tmpl" \
  >"$test_home/.local/bin/restic-archive"
chmod 755 "$test_home/.local/bin/restic-archive"
shellcheck "$test_home/.local/bin/restic-archive"

restic_bin=$(mise exec restic@0.19.1 -- which restic)
ln -s "$restic_bin" "$test_home/.local/bin/restic"
export XDG_STATE_HOME="$test_home/.local/state"
cat >"$config_dir/b2.env" <<EOF
AWS_ACCESS_KEY_ID=fixture-access
AWS_SECRET_ACCESS_KEY=fixture-secret
RESTIC_REPOSITORY_BASE=$temporary/restic-repository
RESTIC_PASSWORD=fixture-password
EOF
chmod 600 "$config_dir/b2.env"

printf '%s\n' keep >"$temporary/source/keep"
printf 'Signature: 8a477f597d28d172789f06886806bc55\n' \
  >"$temporary/source/cache/CACHEDIR.TAG"
printf '%s\n' ignore >"$temporary/source/cache/payload"
printf '%s\n' "$temporary/source" >"$temporary/manifest"

HOME="$test_home" "$test_home/.local/bin/restic-archive" init >/dev/null
HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  backup external-ssd-secondary "$temporary/manifest" --dry-run --quiet
HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  backup external-ssd-secondary "$temporary/manifest" --quiet
HOME="$test_home" "$test_home/.local/bin/restic-archive" check >/dev/null
HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  snapshots --host external-ssd-secondary --tag manual-archive --compact \
  >"$temporary/snapshots"
grep -Fq external-ssd-secondary "$temporary/snapshots"
grep -Fq manual-archive "$temporary/snapshots"

HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  ls latest --host external-ssd-secondary >"$temporary/list"
grep -Fq "$temporary/source/keep" "$temporary/list"
grep -Fq "$temporary/manifest" "$temporary/list"
if grep -Fq "$temporary/source/cache/payload" "$temporary/list"; then
  printf 'restic-archive included a tagged cache directory\n' >&2
  exit 1
fi

mkdir "$temporary/restore"
HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  restore "latest:$temporary/source" --host external-ssd-secondary \
  --target "$temporary/restore" >/dev/null
cmp "$temporary/source/keep" "$temporary/restore/keep"

mount_fake="$temporary/mount-fake"
cat >"$mount_fake" <<'EOF'
#!/bin/sh
printf '%s\n' "$@" >"$RESTIC_ARCHIVE_CAPTURE_FILE"
EOF
chmod 755 "$mount_fake"
mkdir "$temporary/mount"
HOME="$test_home" RESTIC_ARCHIVE_RESTIC_BIN="$mount_fake" \
  RESTIC_ARCHIVE_CAPTURE_FILE="$temporary/mount-args" \
  "$test_home/.local/bin/restic-archive" mount "$temporary/mount" \
  --host external-ssd-secondary
grep -Fxq 'mount' "$temporary/mount-args"
grep -Fxq "$temporary/mount" "$temporary/mount-args"
grep -Fxq -- '--host' "$temporary/mount-args"
grep -Fxq 'external-ssd-secondary' "$temporary/mount-args"

mount_cancel_fake="$temporary/mount-cancel-fake"
cat >"$mount_cancel_fake" <<'EOF'
#!/bin/sh
trap 'exit 0' INT TERM
kill -INT "$PPID"
exit 0
EOF
chmod 755 "$mount_cancel_fake"
HOME="$test_home" RESTIC_ARCHIVE_RESTIC_BIN="$mount_cancel_fake" \
  "$test_home/.local/bin/restic-archive" mount "$temporary/mount"
cancel_record=$(find "$state_dir/runs" -type f -name '*.cancel' -print -quit)
test -n "$cancel_record"
grep -Fxq 'operation=mount' "$cancel_record"
grep -Fxq 'status=cancel' "$cancel_record"
grep -Fxq 'error_type=cancelled' "$cancel_record"
grep -Fxq 'exit_code=0' "$cancel_record"
grep -Fxq 'recording_completeness=complete' "$cancel_record"

success_count=$(find "$state_dir/runs" -type f -name '*.success' | wc -l)
if ((success_count < 5)); then
  printf 'restic-archive did not retain successful diagnostic runs\n' >&2
  exit 1
fi
grep -R -Fq 'operation=backup' "$state_dir/runs"
grep -R -Fq 'operation=mount' "$state_dir/runs"
grep -R -Fq 'dry_run=true' "$state_dir/runs"
grep -R -Fq 'dry_run=false' "$state_dir/runs"
grep -R -Fq 'status=success' "$state_dir/runs"
grep -R -Fq 'recording_completeness=complete' "$state_dir/runs"
if grep -R -Fq 'fixture-secret' "$state_dir"; then
  printf 'restic-archive recorded a credential\n' >&2
  exit 1
fi

for _ in $(seq 1 55); do
  HOME="$test_home" "$test_home/.local/bin/restic-archive" unsupported \
    >/dev/null 2>&1 || true
done
failure_count=$(find "$state_dir/runs" -type f -name '*.error' | wc -l)
if ((failure_count != 50)); then
  printf 'restic-archive retained %s failed runs instead of 50\n' "$failure_count" >&2
  exit 1
fi

before=$(find "$state_dir/runs" -type f | wc -l)
HOME="$test_home" RESTIC_ARCHIVE_RECORDING=off \
  "$test_home/.local/bin/restic-archive" snapshots --compact >/dev/null
after=$(find "$state_dir/runs" -type f | wc -l)
if ((before != after)); then
  printf 'restic-archive recorded a run while recording was disabled\n' >&2
  exit 1
fi

printf 'relative/path\n' >"$temporary/invalid-manifest"
if HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  backup invalid-source "$temporary/invalid-manifest" >/dev/null 2>&1; then
  printf 'restic-archive accepted a relative manifest path\n' >&2
  exit 1
fi
grep -R -Fq 'error_type=manifest_invalid' "$state_dir/runs"

fixture_secret='FixtureSecretMustNotBeRecorded'
if HOME="$test_home" "$test_home/.local/bin/restic-archive" "$fixture_secret" \
  >/dev/null 2>&1; then
  printf 'restic-archive accepted an unknown action\n' >&2
  exit 1
fi
if HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  backup "$fixture_secret" "$temporary/manifest" >/dev/null 2>&1; then
  printf 'restic-archive accepted an invalid archive ID\n' >&2
  exit 1
fi
if grep -R -Fq "$fixture_secret" "$state_dir"; then
  printf 'restic-archive recorded an unvalidated argument\n' >&2
  exit 1
fi

mkdir "$temporary/restore-delete-target"
printf '%s\n' sentinel >"$temporary/restore-delete-target/sentinel"
if HOME="$test_home" "$test_home/.local/bin/restic-archive" \
  restore latest --host external-ssd-secondary \
  --target "$temporary/restore-delete-target" --delete >/dev/null 2>&1; then
  printf 'restic-archive accepted restore --delete\n' >&2
  exit 1
fi
test -f "$temporary/restore-delete-target/sentinel"

recording_fake="$temporary/recording-fake"
cat >"$recording_fake" <<'EOF'
#!/bin/sh
find "$XDG_STATE_HOME/restic-archive/runs" -type f -name '*.pending' \
  -exec chmod 400 {} +
exit 0
EOF
chmod 755 "$recording_fake"
HOME="$test_home" RESTIC_ARCHIVE_RESTIC_BIN="$recording_fake" \
  "$test_home/.local/bin/restic-archive" snapshots \
  >"$temporary/recording-on.stdout" 2>"$temporary/recording-on.stderr"
HOME="$test_home" RESTIC_ARCHIVE_RESTIC_BIN="$recording_fake" \
  RESTIC_ARCHIVE_RECORDING=off \
  "$test_home/.local/bin/restic-archive" snapshots \
  >"$temporary/recording-off.stdout" 2>"$temporary/recording-off.stderr"
cmp "$temporary/recording-on.stdout" "$temporary/recording-off.stdout"
cmp "$temporary/recording-on.stderr" "$temporary/recording-off.stderr"
test "$(find "$state_dir/runs" -type f -name '*.partial' | wc -l)" -ge 1

rename_fake="$temporary/rename-fake"
cat >"$rename_fake" <<'EOF'
#!/bin/sh
chmod 500 "$XDG_STATE_HOME/restic-archive/runs"
exit 0
EOF
chmod 755 "$rename_fake"
HOME="$test_home" RESTIC_ARCHIVE_RESTIC_BIN="$rename_fake" \
  "$test_home/.local/bin/restic-archive" snapshots \
  >"$temporary/rename-on.stdout" 2>"$temporary/rename-on.stderr"
chmod 700 "$state_dir/runs"
HOME="$test_home" RESTIC_ARCHIVE_RESTIC_BIN="$rename_fake" \
  RESTIC_ARCHIVE_RECORDING=off \
  "$test_home/.local/bin/restic-archive" snapshots \
  >"$temporary/rename-off.stdout" 2>"$temporary/rename-off.stderr"
chmod 700 "$state_dir/runs"
cmp "$temporary/rename-on.stdout" "$temporary/rename-off.stdout"
cmp "$temporary/rename-on.stderr" "$temporary/rename-off.stderr"

chmod 644 "$config_dir/b2.env"
if HOME="$test_home" "$test_home/.local/bin/restic-archive" snapshots \
  >/dev/null 2>&1; then
  printf 'restic-archive accepted an insecure credential file\n' >&2
  exit 1
fi
grep -R -Fq 'error_type=configuration_invalid' "$state_dir/runs"

nonsecret_data='{"roles":[],"chezmoi":{"hostname":"cristina","os":"linux"}}'
windows_data='{"roles":["secrets"],"chezmoi":{"hostname":"cristina","os":"windows"}}'
for disabled_data in "$nonsecret_data" "$windows_data"; do
  if chezmoi managed --source "$repository" --override-data "$disabled_data" |
    grep -Fxq '.local/bin/restic-archive'; then
    printf 'unsupported host managed restic-archive\n' >&2
    exit 1
  fi
done
enabled=$(chezmoi managed --source "$repository" --override-data "$data")
grep -Fxq '.local/bin/restic-archive' <<<"$enabled"

printf 'Restic manual archive tests passed\n'
