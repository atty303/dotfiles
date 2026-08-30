#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
export RESTIC_CACHE_DIR="$temporary/restic-cache"
mkdir -p "$RESTIC_CACHE_DIR"

test_home="$temporary/home"
config_dir="$test_home/.config/restic"
chezmoi_config="$temporary/chezmoi.toml"
host=cristina
printf 'encryption = "age"\n' >"$chezmoi_config"
mkdir -p \
  "$test_home/.local/bin" \
  "$config_dir" \
  "$test_home/Documents" \
  "$test_home/.cache" \
  "$test_home/.local/share/Steam/userdata" \
  "$test_home/.local/share/Steam/steamapps/common" \
  "$test_home/.local/share/Steam/steamapps/compatdata" \
  "$test_home/.local/share/containers/storage/volumes/anonymous/_data" \
  "$test_home/.local/share/containers/storage/volumes/zmk-config/_data" \
  "$test_home/.var/app/example/data" \
  "$test_home/Games/Heroic" \
  "$test_home/src/example/node_modules"

data=$(printf '{"roles":["secrets"],"chezmoi":{"hostname":"%s","os":"linux","homeDir":"%s"}}' \
  "$host" "$test_home")
chezmoi execute-template --source "$repository" --override-data "$data" \
  <"$repository/home/dot_local/bin/executable_restic-home.tmpl" \
  >"$test_home/.local/bin/restic-home"
chezmoi execute-template --source "$repository" --override-data "$data" \
  <"$repository/home/dot_config/private_restic/excludes.tmpl" \
  >"$config_dir/excludes"
chmod 755 "$test_home/.local/bin/restic-home"

restic_bin=$(command -v restic)
ln -s "$restic_bin" "$test_home/.local/bin/restic"
cat >"$config_dir/b2.env" <<EOF
AWS_ACCESS_KEY_ID=fixture-access
AWS_SECRET_ACCESS_KEY=fixture-secret
RESTIC_REPOSITORY_BASE=$temporary/repository
RESTIC_PASSWORD=fixture-password
EOF
chmod 600 "$config_dir/b2.env"

printf '%s\n' keep >"$test_home/Documents/keep"
printf '%s\n' ignore >"$test_home/.cache/ignored"
printf '%s\n' keep >"$test_home/.local/share/Steam/userdata/save"
printf '%s\n' ignore >"$test_home/.local/share/Steam/steamapps/common/game"
printf '%s\n' keep >"$test_home/.local/share/Steam/steamapps/compatdata/prefix"
printf '%s\n' ignore >"$test_home/.local/share/containers/storage/volumes/anonymous/_data/cache"
printf '%s\n' keep >"$test_home/.local/share/containers/storage/volumes/zmk-config/_data/config"
printf '%s\n' keep >"$test_home/.var/app/example/data/state"
printf '%s\n' ignore >"$test_home/Games/Heroic/game"
printf '%s\n' ignore >"$test_home/src/example/node_modules/dependency"

HOME="$test_home" "$test_home/.local/bin/restic-home" init >/dev/null
HOME="$test_home" "$test_home/.local/bin/restic-home" backup --quiet
HOME="$test_home" "$test_home/.local/bin/restic-home" snapshots --compact >"$temporary/snapshots"
grep -Fq automatic "$temporary/snapshots"

HOME="$test_home" "$test_home/.local/bin/restic-home" ls latest --recursive >"$temporary/list"
for included in \
  "$test_home/Documents/keep" \
  "$test_home/.local/share/Steam/userdata/save" \
  "$test_home/.local/share/Steam/steamapps/compatdata/prefix" \
  "$test_home/.local/share/containers/storage/volumes/zmk-config/_data/config" \
  "$test_home/.var/app/example/data/state"; do
  grep -Fxq "$included" "$temporary/list"
done
for excluded in \
  "$test_home/.cache/ignored" \
  "$test_home/.local/share/Steam/steamapps/common/game" \
  "$test_home/.local/share/containers/storage/volumes/anonymous/_data/cache" \
  "$test_home/Games/Heroic/game" \
  "$test_home/src/example/node_modules/dependency"; do
  if grep -Fxq "$excluded" "$temporary/list"; then
    printf 'excluded restic fixture was backed up: %s\n' "$excluded" >&2
    exit 1
  fi
done

HOME="$test_home" "$test_home/.local/bin/restic-home" maintenance >/dev/null
HOME="$test_home" "$test_home/.local/bin/restic-home" check >/dev/null
mkdir "$temporary/restore"
HOME="$test_home" "$test_home/.local/bin/restic-home" restore "latest:$test_home/Documents" \
  --target "$temporary/restore" >/dev/null
cmp "$test_home/Documents/keep" "$temporary/restore/keep"

chmod 644 "$config_dir/b2.env"
if HOME="$test_home" "$test_home/.local/bin/restic-home" snapshots \
  >"$temporary/insecure.out" 2>&1; then
  printf 'restic-home accepted an insecure credential file\n' >&2
  exit 1
fi
grep -Fq 'must have mode 600 or 400' "$temporary/insecure.out"
chmod 600 "$config_dir/b2.env"
for rejected in \
  'backup --host override' \
  'maintenance --keep-daily 1' \
  'check --read-data-subset=100%'; do
  read -r -a rejected_args <<<"$rejected"
  if HOME="$test_home" "$test_home/.local/bin/restic-home" "${rejected_args[@]}" \
    >"$temporary/rejected.out" 2>&1; then
    printf 'restic-home accepted an invariant override: %s\n' "$rejected" >&2
    exit 1
  fi
  grep -Fq 'unsupported option for restic-home' "$temporary/rejected.out"
done

cp "$config_dir/b2.env" "$temporary/valid-b2.env"
for invalid_name in legacy duplicate missing unknown; do
  case $invalid_name in
    legacy)
      printf '%s\n' \
        'AWS_ACCESS_KEY_ID=fixture-access' \
        'AWS_SECRET_ACCESS_KEY=fixture-secret' \
        "RESTIC_REPOSITORY=$temporary/repository/$host" \
        'RESTIC_PASSWORD=fixture-password' >"$config_dir/b2.env"
      ;;
    duplicate)
      cp "$temporary/valid-b2.env" "$config_dir/b2.env"
      printf '%s\n' 'RESTIC_PASSWORD=duplicate' >>"$config_dir/b2.env"
      ;;
    missing)
      printf '%s\n' \
        'AWS_ACCESS_KEY_ID=fixture-access' \
        'AWS_SECRET_ACCESS_KEY=fixture-secret' \
        "RESTIC_REPOSITORY_BASE=$temporary/repository" >"$config_dir/b2.env"
      ;;
    unknown)
      cp "$temporary/valid-b2.env" "$config_dir/b2.env"
      printf '%s\n' 'RESTIC_UNKNOWN=value' >>"$config_dir/b2.env"
      ;;
  esac
  chmod 600 "$config_dir/b2.env"
  if HOME="$test_home" "$test_home/.local/bin/restic-home" snapshots \
    >"$temporary/$invalid_name.out" 2>&1; then
    printf 'restic-home accepted invalid shared configuration: %s\n' "$invalid_name" >&2
    exit 1
  fi
done
cp "$temporary/valid-b2.env" "$config_dir/b2.env"
chmod 600 "$config_dir/b2.env"
mv "$config_dir/b2.env" "$config_dir/b2-target.env"
ln -s b2-target.env "$config_dir/b2.env"
if HOME="$test_home" "$test_home/.local/bin/restic-home" snapshots \
  >"$temporary/symlink.out" 2>&1; then
  printf 'restic-home accepted a symlinked shared configuration\n' >&2
  exit 1
fi
rm "$config_dir/b2.env"
mv "$config_dir/b2-target.env" "$config_dir/b2.env"

capture_fake="$temporary/restic-capture"
cat >"$capture_fake" <<'EOF'
#!/bin/sh
printf '%s\n' "$RESTIC_REPOSITORY" >"$RESTIC_CAPTURE_REPOSITORY"
printf '%s\n' "$@" >"$RESTIC_CAPTURE_ARGUMENTS"
EOF
chmod 755 "$capture_fake"
HOME="$test_home" RESTIC_HOME_RESTIC_BIN="$capture_fake" \
  RESTIC_CAPTURE_REPOSITORY="$temporary/captured-repository" \
  RESTIC_CAPTURE_ARGUMENTS="$temporary/captured-arguments" \
  "$test_home/.local/bin/restic-home" backup --dry-run
grep -Fxq "$temporary/repository/$host" "$temporary/captured-repository"
grep -Fxq -- '--host' "$temporary/captured-arguments"
grep -Fxq "$host" "$temporary/captured-arguments"
if grep -Fq fixture-secret "$temporary/captured-repository" \
  "$temporary/captured-arguments"; then
  printf 'restic-home exposed a credential to its non-secret capture surface\n' >&2
  exit 1
fi

printf '%s\n' wrong-password >"$temporary/wrong-password"
printf '%s\n' "$temporary/wrong-repository" >"$temporary/wrong-repository-file"
for inherited_name in password_file password_command repository_file; do
  case $inherited_name in
    password_file)
      HOME="$test_home" RESTIC_PASSWORD_FILE="$temporary/wrong-password" \
        "$test_home/.local/bin/restic-home" snapshots --compact >/dev/null
      ;;
    password_command)
      HOME="$test_home" RESTIC_PASSWORD_COMMAND=false \
        "$test_home/.local/bin/restic-home" snapshots --compact >/dev/null
      ;;
    repository_file)
      HOME="$test_home" RESTIC_REPOSITORY_FILE="$temporary/wrong-repository-file" \
        "$test_home/.local/bin/restic-home" snapshots --compact >/dev/null
      ;;
  esac
done

unit_dir="$temporary/units"
mkdir "$unit_dir"
for source in \
  "$repository"/home/dot_config/systemd/user/restic-*.service.tmpl \
  "$repository"/home/dot_config/systemd/user/restic-*.timer.tmpl; do
  target="$unit_dir/$(basename "${source%.tmpl}")"
  chezmoi execute-template --source "$repository" --override-data "$data" \
    <"$source" >"$target"
done
SYSTEMD_UNIT_PATH="$unit_dir:/usr/lib/systemd/user" systemd-analyze --user verify \
  "$unit_dir"/*.service "$unit_dir"/*.timer

nonsecret_data='{"roles":[],"chezmoi":{"hostname":"cristina","os":"linux"}}'
unknown_data='{"roles":["secrets"],"chezmoi":{"hostname":"unknown","os":"linux"}}'
second_data='{"roles":["secrets"],"restic":{"hosts":{"alex":{"enabled":true,"backup_calendar":"*-*-* 03:00:00","maintenance_calendar":"Sun *-*-* 05:00:00","check_calendar":"*-*-01 07:00:00"}}},"chezmoi":{"hostname":"alex","os":"linux","homeDir":"/home/alex"}}'
first_two_data='{"roles":["secrets"],"restic":{"hosts":{"alex":{"enabled":true,"backup_calendar":"*-*-* 03:00:00","maintenance_calendar":"Sun *-*-* 05:00:00","check_calendar":"*-*-01 07:00:00"}}},"chezmoi":{"hostname":"cristina","os":"linux","homeDir":"/home/atty"}}'
nonsecret_managed=$(chezmoi --config "$chezmoi_config" managed --source "$repository" \
  --override-data "$nonsecret_data")
if grep -Eq '^\.local/bin/restic-home$|^\.config/systemd/user/restic-' <<<"$nonsecret_managed"; then
  printf 'non-secret host managed restic home CLI or automation\n' >&2
  exit 1
fi
unknown_managed=$(chezmoi --config "$chezmoi_config" managed --source "$repository" \
  --override-data "$unknown_data")
grep -Fxq '.local/bin/restic-home' <<<"$unknown_managed"
if grep -Eq '^\.config/restic/excludes$|^\.config/systemd/user/restic-' <<<"$unknown_managed"; then
  printf 'unregistered secret host managed restic home automation\n' >&2
  exit 1
fi
chezmoi execute-template --source "$repository" --override-data "$unknown_data" \
  <"$repository/home/dot_local/bin/executable_restic-home.tmpl" \
  >"$temporary/restic-home-unknown"
chmod 755 "$temporary/restic-home-unknown"
if HOME="$test_home" RESTIC_HOME_CONFIG_DIR="$temporary/missing-restic-config" \
  "$temporary/restic-home-unknown" backup >"$temporary/unknown-backup.out" 2>&1; then
  printf 'unregistered host ran a Restic repository command\n' >&2
  exit 1
fi
grep -Fq 'run restic-home add-host' "$temporary/unknown-backup.out"

enabled=$(chezmoi --config "$chezmoi_config" managed --source "$repository" \
  --override-data "$data")
grep -Fxq '.local/bin/restic-home' <<<"$enabled"
grep -Fxq '.config/systemd/user/restic-backup.timer' <<<"$enabled"
if grep -Fq '.config/systemd/user/timers.target.wants/restic-' <<<"$enabled"; then
  printf 'timer activation was included in the source state\n' >&2
  exit 1
fi
two_host_source="$temporary/two-host-source"
cp -a "$repository" "$two_host_source"
second_enabled=$(chezmoi --config "$chezmoi_config" managed --source "$two_host_source" \
  --override-data "$second_data")
grep -Fxq '.local/bin/restic-home' <<<"$second_enabled"
grep -Fxq '.config/restic/b2.env' <<<"$second_enabled"
if grep -Eq '^\.config/restic/(credentials|passwords)/' <<<"$second_enabled"; then
  printf 'an enabled host managed a legacy restic secret\n' >&2
  exit 1
fi
first_enabled=$(chezmoi --config "$chezmoi_config" managed --source "$two_host_source" \
  --override-data "$first_two_data")
grep -Fxq '.config/restic/b2.env' <<<"$first_enabled"
chezmoi execute-template --source "$two_host_source" --override-data "$second_data" \
  <"$two_host_source/home/dot_local/bin/executable_restic-home.tmpl" \
  >"$temporary/restic-home-alex"
chmod 755 "$temporary/restic-home-alex"
HOME="$test_home" RESTIC_HOME_CONFIG_DIR="$config_dir" \
  RESTIC_HOME_RESTIC_BIN="$capture_fake" \
  RESTIC_CAPTURE_REPOSITORY="$temporary/alex-repository" \
  RESTIC_CAPTURE_ARGUMENTS="$temporary/alex-arguments" \
  "$temporary/restic-home-alex" backup --dry-run
grep -Fxq "$temporary/repository/alex" "$temporary/alex-repository"
grep -Fxq alex "$temporary/alex-arguments"

foreign_home="$temporary/foreign-home"
mkdir -p "$foreign_home/.config/restic/credentials" "$foreign_home/.config/restic/passwords"
touch "$foreign_home/.config/restic/b2.env"
touch "$foreign_home/.config/restic/credentials/cristina.env" \
  "$foreign_home/.config/restic/credentials/manual-archives.env" \
  "$foreign_home/.config/restic/passwords/cristina" \
  "$foreign_home/.config/restic/passwords/manual-archives"
chezmoi execute-template --source "$repository" --override-data "$second_data" \
  <"$repository/home/.chezmoiscripts/linux/run_onchange_after_restic-disable.sh.tmpl" \
  >"$temporary/restic-foreign-cleanup.sh"
HOME="$foreign_home" sh "$temporary/restic-foreign-cleanup.sh"
test -f "$foreign_home/.config/restic/b2.env"
test ! -e "$foreign_home/.config/restic/credentials"
test ! -e "$foreign_home/.config/restic/passwords"

transition_home="$temporary/transition-home"
transition_bin="$temporary/transition-bin"
mkdir -p \
  "$transition_home/.local/bin" \
  "$transition_home/.config/restic/credentials" \
  "$transition_home/.config/restic/passwords" \
  "$transition_home/.config/systemd/user/timers.target.wants" \
  "$transition_bin"
touch \
  "$transition_home/.local/bin/restic-home" \
  "$transition_home/.local/bin/restic-archive" \
  "$transition_home/.config/restic/excludes" \
  "$transition_home/.config/restic/b2.env" \
  "$transition_home/.config/restic/credentials/cristina.env" \
  "$transition_home/.config/restic/credentials/manual-archives.env" \
  "$transition_home/.config/restic/credentials/retired.env" \
  "$transition_home/.config/restic/credentials/.retired" \
  "$transition_home/.config/restic/credentials/retired.env.bak" \
  "$transition_home/.config/restic/passwords/cristina" \
  "$transition_home/.config/restic/passwords/manual-archives" \
  "$transition_home/.config/restic/passwords/retired" \
  "$transition_home/.config/restic/passwords/.retired" \
  "$transition_home/.config/systemd/user/restic-backup.service" \
  "$transition_home/.config/systemd/user/restic-backup.timer" \
  "$transition_home/.config/systemd/user/restic-check.service" \
  "$transition_home/.config/systemd/user/restic-check.timer" \
  "$transition_home/.config/systemd/user/restic-failure-notify@.service" \
  "$transition_home/.config/systemd/user/restic-maintenance.service" \
  "$transition_home/.config/systemd/user/restic-maintenance.timer" \
  "$transition_home/.config/systemd/user/timers.target.wants/restic-backup.timer" \
  "$transition_home/.config/systemd/user/timers.target.wants/restic-check.timer" \
  "$transition_home/.config/systemd/user/timers.target.wants/restic-maintenance.timer"
cat >"$transition_bin/systemctl" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$SYSTEMCTL_LOG"
case $* in
  '--user is-active '*) printf '%s\n' inactive; exit 3 ;;
  '--user is-enabled '*) printf '%s\n' enabled ;;
esac
EOF
chmod 755 "$transition_bin/systemctl"
chezmoi execute-template --source "$repository" --override-data "$unknown_data" \
  <"$repository/home/.chezmoiscripts/linux/run_onchange_after_restic-disable.sh.tmpl" \
  >"$temporary/restic-disable.sh"
HOME="$transition_home" PATH="$transition_bin:$PATH" \
  SYSTEMCTL_LOG="$temporary/systemctl.log" sh "$temporary/restic-disable.sh"
test -f "$transition_home/.local/bin/restic-archive"
test -f "$transition_home/.local/bin/restic-home"
test -f "$transition_home/.config/restic/b2.env"
test ! -e "$transition_home/.config/restic/credentials"
test ! -e "$transition_home/.config/restic/passwords"
if find "$transition_home" \( -type f -o -type l \) \
  ! -path "$transition_home/.local/bin/restic-archive" \
  ! -path "$transition_home/.local/bin/restic-home" \
  ! -path "$transition_home/.config/restic/b2.env" | grep -q .; then
  printf 'disabled home backup retained home automation or legacy secrets\n' >&2
  exit 1
fi
for timer in restic-backup.timer restic-maintenance.timer restic-check.timer; do
  grep -Fq -- "--user disable $timer" "$temporary/systemctl.log"
done

archive_empty_home="$temporary/archive-empty-home"
mkdir -p "$archive_empty_home/.config/restic"
HOME="$archive_empty_home" sh "$temporary/restic-disable.sh"
test -d "$archive_empty_home/.config/restic"

nonsecret_home="$temporary/nonsecret-home"
mkdir -p \
  "$nonsecret_home/.local/bin" \
  "$nonsecret_home/.config/restic/credentials" \
  "$nonsecret_home/.config/restic/passwords"
touch \
  "$nonsecret_home/.local/bin/restic-home" \
  "$nonsecret_home/.local/bin/restic-archive" \
  "$nonsecret_home/.config/restic/b2.env" \
  "$nonsecret_home/.config/restic/credentials/manual-archives.env" \
  "$nonsecret_home/.config/restic/passwords/manual-archives"
chezmoi execute-template --source "$repository" --override-data "$nonsecret_data" \
  <"$repository/home/.chezmoiscripts/linux/run_onchange_after_restic-disable.sh.tmpl" \
  >"$temporary/restic-nonsecret-disable.sh"
HOME="$nonsecret_home" sh "$temporary/restic-nonsecret-disable.sh"
if find "$nonsecret_home" \( -type f -o -type l \) | grep -q .; then
  printf 'non-secret host retained manual archive credentials or wrapper\n' >&2
  exit 1
fi

nonsecret_failure_home="$temporary/nonsecret-failure-home"
mkdir -p \
  "$nonsecret_failure_home/.local/bin" \
  "$nonsecret_failure_home/.config/restic/credentials" \
  "$nonsecret_failure_home/.config/restic/passwords" \
  "$nonsecret_failure_home/.config/systemd/user"
touch \
  "$nonsecret_failure_home/.local/bin/restic-home" \
  "$nonsecret_failure_home/.local/bin/restic-archive" \
  "$nonsecret_failure_home/.config/restic/b2.env" \
  "$nonsecret_failure_home/.config/restic/credentials/cristina.env" \
  "$nonsecret_failure_home/.config/restic/credentials/manual-archives.env" \
  "$nonsecret_failure_home/.config/restic/passwords/cristina" \
  "$nonsecret_failure_home/.config/restic/passwords/manual-archives" \
  "$nonsecret_failure_home/.config/systemd/user/restic-check.timer"
cat >"$transition_bin/systemctl" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$transition_bin/systemctl"
if HOME="$nonsecret_failure_home" PATH="$transition_bin:$PATH" \
  sh "$temporary/restic-nonsecret-disable.sh" >/dev/null 2>&1; then
  printf 'non-secret cleanup ignored a user manager failure\n' >&2
  exit 1
fi
test ! -e "$nonsecret_failure_home/.local/bin/restic-archive"
test -f "$nonsecret_failure_home/.local/bin/restic-home"
test -f "$nonsecret_failure_home/.config/restic/b2.env"
test -f "$nonsecret_failure_home/.config/restic/credentials/cristina.env"
test -f "$nonsecret_failure_home/.config/restic/passwords/cristina"
test -f "$nonsecret_failure_home/.config/systemd/user/restic-check.timer"

failure_home="$temporary/failure-home"
cp -a "$transition_home" "$failure_home"
mkdir -p \
  "$failure_home/.local/bin" \
  "$failure_home/.config/restic/credentials" \
  "$failure_home/.config/restic/passwords" \
  "$failure_home/.config/systemd/user"
touch \
  "$failure_home/.local/bin/restic-home" \
  "$failure_home/.config/restic/b2.env" \
  "$failure_home/.config/restic/credentials/retired.env" \
  "$failure_home/.config/restic/passwords/retired" \
  "$failure_home/.config/systemd/user/restic-check.timer"
cat >"$transition_bin/systemctl" <<'EOF'
#!/bin/sh
exit 1
EOF
chmod 755 "$transition_bin/systemctl"
if HOME="$failure_home" PATH="$transition_bin:$PATH" \
  SYSTEMCTL_LOG="$temporary/systemctl-failure.log" sh "$temporary/restic-disable.sh" \
  >"$temporary/disable-failure.out" 2>&1; then
  printf 'restic disable transition ignored a user manager failure\n' >&2
  exit 1
fi
grep -Fq 'Could not contact the systemd user manager' "$temporary/disable-failure.out"
test -f "$failure_home/.local/bin/restic-home"
test -f "$failure_home/.config/restic/b2.env"
test -f "$failure_home/.config/restic/credentials/retired.env"
test -f "$failure_home/.config/restic/passwords/retired"

query_failure_home="$temporary/query-failure-home"
cp -a "$failure_home" "$query_failure_home"
cat >"$transition_bin/systemctl" <<'EOF'
#!/bin/sh
case $* in
  '--user show-environment') exit 0 ;;
  *) exit 1 ;;
esac
EOF
chmod 755 "$transition_bin/systemctl"
if HOME="$query_failure_home" PATH="$transition_bin:$PATH" \
  sh "$temporary/restic-disable.sh" >"$temporary/query-failure.out" 2>&1; then
  printf 'restic disable transition ignored a timer query failure\n' >&2
  exit 1
fi
grep -Fq 'Could not query restic user timer state' "$temporary/query-failure.out"
test -f "$query_failure_home/.config/restic/credentials/retired.env"

post_stop_home="$temporary/post-stop-home"
cp -a "$failure_home" "$post_stop_home"
touch "$post_stop_home/.config/systemd/user/restic-backup.timer"
cat >"$transition_bin/systemctl" <<'EOF'
#!/bin/sh
case $* in
  '--user show-environment') exit 0 ;;
  '--user is-active restic-backup.timer')
    if [ ! -e "$SYSTEMCTL_COUNT" ]; then
      : >"$SYSTEMCTL_COUNT"
      printf '%s\n' active
      exit 0
    fi
    exit 1
    ;;
  '--user stop restic-backup.timer') exit 0 ;;
  *) printf '%s\n' inactive; exit 3 ;;
esac
EOF
chmod 755 "$transition_bin/systemctl"
if HOME="$post_stop_home" PATH="$transition_bin:$PATH" \
  SYSTEMCTL_COUNT="$temporary/systemctl-count" sh "$temporary/restic-disable.sh" \
  >"$temporary/post-stop-failure.out" 2>&1; then
  printf 'restic disable transition ignored a post-stop query failure\n' >&2
  exit 1
fi
grep -Fq 'Could not verify stopped restic user timer' "$temporary/post-stop-failure.out"
test -f "$post_stop_home/.config/restic/credentials/retired.env"
test -f "$post_stop_home/.config/systemd/user/restic-backup.timer"

onboarding_home="$temporary/onboarding-home"
onboarding_source="$temporary/onboarding-source"
onboarding_bin="$temporary/onboarding-bin"
onboarding_state="$temporary/onboarding-state"
onboarding_runtime="$temporary/onboarding-runtime"
onboarding_command="$temporary/restic-home-onboarding"
script_bin=$(command -v script)
onboarding_log="$temporary/onboarding-runtime.log"
systemctl_log="$temporary/onboarding-systemctl.log"
repository_marker="$temporary/onboarding-repository"
timer_marker="$temporary/onboarding-timers-active"
mkdir -p \
  "$onboarding_home/.local/bin" \
  "$onboarding_source/.chezmoidata" \
  "$onboarding_bin" \
  "$onboarding_state"
cp "$repository/home/.chezmoidata/restic.toml" \
  "$onboarding_source/.chezmoidata/restic.toml"
onboarding_data=$(printf '{"roles":["secrets"],"chezmoi":{"hostname":"new-host","os":"linux","homeDir":"%s"}}' \
  "$onboarding_home")
chezmoi execute-template --source "$repository" --override-data "$onboarding_data" \
  <"$repository/home/dot_local/bin/executable_restic-home.tmpl" \
  >"$onboarding_command"
chmod 755 "$onboarding_command"

cat >"$onboarding_runtime" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_RESTIC_LOG"
case ${1-} in
  snapshots)
    [[ -e $FAKE_REPOSITORY_MARKER ]] || exit 1
    if [[ ${2-} == --json ]]; then
      printf '[]\n'
    else
      printf 'fixture snapshot for new-host\n'
    fi
    ;;
  init)
    printf 's3:https://fixture.invalid/restic/new-host\n'
    printf 'fixture-secret-child\n' >&2
    [[ ${FAKE_INIT_FAIL:-false} != true ]] || exit 1
    : >"$FAKE_REPOSITORY_MARKER"
    ;;
  backup)
    printf 's3:https://fixture.invalid/restic/new-host\n'
    printf 'fixture-secret-child\n' >&2
    [[ ${FAKE_BACKUP_FAIL:-false} != true ]] || exit 1
    : >"$FAKE_REPOSITORY_MARKER"
    ;;
  check)
    printf 's3:https://fixture.invalid/restic/new-host\n'
    printf 'fixture-secret-child\n' >&2
    [[ ${FAKE_CHECK_FAIL:-false} != true ]] || exit 1
    ;;
  restore)
    printf 's3:https://fixture.invalid/restic/new-host\n'
    printf 'fixture-secret-child\n' >&2
    target=""
    shift
    while (($#)); do
      case $1 in
        --target)
          target=$2
          shift 2
          ;;
        *) shift ;;
      esac
    done
    restored="$target/${HOME#/}/.config/restic/excludes"
    mkdir -p "$(dirname -- "$restored")"
    if [[ ${FAKE_RESTORE_MISMATCH:-false} == true ]]; then
      printf 'mismatch\n' >"$restored"
    else
      cp "$HOME/.config/restic/excludes" "$restored"
    fi
    ;;
  *)
    printf 'unexpected fake restic-home action: %s\n' "${1-}" >&2
    exit 1
    ;;
esac
EOF
chmod 755 "$onboarding_runtime"

cat >"$onboarding_bin/chezmoi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case ${1-} in
  source-path)
    printf '%s\n' "$FAKE_SOURCE_DIR"
    ;;
  execute-template)
    template=${2-}
    source_file="$FAKE_SOURCE_DIR/.chezmoidata/restic.toml"
    if [[ $template == *'hasKey .restic.hosts .chezmoi.hostname'* ]]; then
      if grep -Fq '[restic.hosts."new-host"]' "$source_file"; then
        if [[ $template == *'.enabled'* ]]; then
          enabled=$(awk '
            /^\[restic\.hosts\."new-host"\]$/ { in_host=1; next }
            in_host && /^\[/ { exit }
            in_host && /^enabled = / { print $3; exit }
          ' "$source_file")
          [[ $enabled == true ]] && printf 'true\n' || printf 'false\n'
        else
          printf 'true\n'
        fi
      else
        printf 'false\n'
      fi
    elif [[ $template == *'(index .restic.hosts .chezmoi.hostname).enabled'* ]]; then
      awk '
        /^\[restic\.hosts\."new-host"\]$/ { in_host=1; next }
        in_host && /^\[/ { exit }
        in_host && /^enabled = / { print $3; exit }
      ' "$source_file"
    elif [[ $template == *'has "secrets" .roles'* ]]; then
      printf 'true\n'
    elif [[ $template == *'.chezmoi.hostname'* ]]; then
      printf 'new-host\n'
    else
      printf 'unexpected execute-template input: %s\n' "$template" >&2
      exit 1
    fi
    ;;
  apply)
    printf '%s\n' "$*" >>"$FAKE_CHEZMOI_LOG"
    [[ ${FAKE_APPLY_FAIL:-false} != true ]] || exit 1
    mkdir -p "$HOME/.local/bin" "$HOME/.config/restic" "$HOME/.config/systemd/user"
    cp "$FAKE_RESTIC_RUNTIME" "$HOME/.local/bin/restic-home"
    chmod 755 "$HOME/.local/bin/restic-home"
    printf 'fixture excludes\n' >"$HOME/.config/restic/excludes"
    ;;
  *)
    printf 'unexpected fake chezmoi command: %s\n' "${1-}" >&2
    exit 1
    ;;
esac
EOF
chmod 755 "$onboarding_bin/chezmoi"

cat >"$onboarding_bin/gum" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ -n ${FAKE_PENDING_CAPTURE:-} ]]; then
  pending=("$XDG_STATE_HOME"/restic-home/add-host-runs/*.pending)
  [[ -e ${pending[0]} ]] && cp "${pending[0]}" "$FAKE_PENDING_CAPTURE"
fi
case ${1-} in
  confirm)
    [[ ${FAKE_GUM_CANCEL:-false} != true ]]
    ;;
  input)
    header=""
    value=""
    shift
    while (($#)); do
      case $1 in
        --header) header=$2; shift 2 ;;
        --value) value=$2; shift 2 ;;
        *) shift ;;
      esac
    done
    case $header in
      'Backup calendar') printf '%s\n' "${FAKE_BACKUP_CALENDAR:-$value}" ;;
      'Maintenance calendar') printf '%s\n' "${FAKE_MAINTENANCE_CALENDAR:-$value}" ;;
      'Check calendar') printf '%s\n' "${FAKE_CHECK_CALENDAR:-$value}" ;;
      *) exit 1 ;;
    esac
    ;;
  *) exit 1 ;;
esac
EOF
chmod 755 "$onboarding_bin/gum"

cat >"$onboarding_bin/taplo" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1-} == lint ]]
if [[ ${FAKE_SOURCE_CONFLICT:-false} == true ]]; then
  printf '# concurrent change\n' >>"$FAKE_SOURCE_DIR/.chezmoidata/restic.toml"
fi
EOF
chmod 755 "$onboarding_bin/taplo"

cat >"$onboarding_bin/systemd-analyze" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1-} == calendar ]]
[[ ${2-} != invalid ]]
EOF
chmod 755 "$onboarding_bin/systemd-analyze"

cat >"$onboarding_bin/rm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ ${FAKE_RM_FAIL_RESTORE:-false} == true && " $* " == *' -rf '* ]]; then
  exit 1
fi
exec /usr/bin/rm "$@"
EOF
chmod 755 "$onboarding_bin/rm"

cat >"$onboarding_bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
destination=${!#}
if [[ ${FAKE_FINAL_RECORD_MOVE_FAIL:-false} == true && \
  ( $destination == *.success || $destination == *.failure ) ]]; then
  exit 1
fi
if [[ ${FAKE_SOURCE_AFTER_COMPARE_CONFLICT:-false} == true && ${1-} == --exchange ]]; then
  source_file=${!#}
  printf '# concurrent change after compare\n' >>"$source_file"
fi
exec /usr/bin/mv "$@"
EOF
chmod 755 "$onboarding_bin/mv"

cat >"$onboarding_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$FAKE_SYSTEMCTL_LOG"
case $* in
  '--user daemon-reload') ;;
  '--user is-active restic-backup.service' | \
    '--user is-active restic-maintenance.service' | \
    '--user is-active restic-check.service')
    printf 'inactive\n'
    exit 3
    ;;
  '--user is-active restic-backup.timer' | \
    '--user is-active restic-maintenance.timer' | \
    '--user is-active restic-check.timer')
    if [[ ${FAKE_TIMER_MIXED:-false} == true && $* == '--user is-active restic-backup.timer' ]]; then
      printf 'active\n'
      exit 0
    fi
    if [[ -e $FAKE_TIMER_MARKER ]]; then printf 'active\n'; else printf 'inactive\n'; exit 3; fi
    ;;
  '--user is-enabled restic-backup.timer' | \
    '--user is-enabled restic-maintenance.timer' | \
    '--user is-enabled restic-check.timer')
    if [[ ${FAKE_TIMER_MIXED:-false} == true && $* == '--user is-enabled restic-backup.timer' ]]; then
      printf 'enabled\n'
      exit 0
    fi
    if [[ -e $FAKE_TIMER_MARKER ]]; then printf 'enabled\n'; else printf 'disabled\n'; exit 1; fi
    ;;
  '--user enable --now restic-backup.timer restic-maintenance.timer restic-check.timer')
    : >"$FAKE_TIMER_MARKER"
    [[ ${FAKE_ENABLE_FAIL:-false} != true ]]
    ;;
  '--user disable --now restic-backup.timer restic-maintenance.timer restic-check.timer')
    [[ ${FAKE_DISABLE_FAIL:-false} != true ]] || exit 1
    rm -f "$FAKE_TIMER_MARKER"
    ;;
  *)
    printf 'unexpected fake systemctl command: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod 755 "$onboarding_bin/systemctl"

run_onboarding() {
  local source_dir=$1 state_dir=$2 output=$3
  shift 3
  env \
    HOME="$onboarding_home" \
    XDG_STATE_HOME="$state_dir" \
    PATH="$onboarding_bin:/usr/bin:/bin" \
    FAKE_SOURCE_DIR="$source_dir" \
    FAKE_RESTIC_RUNTIME="$onboarding_runtime" \
    FAKE_RESTIC_LOG="$onboarding_log" \
    FAKE_REPOSITORY_MARKER="$repository_marker" \
    FAKE_TIMER_MARKER="$timer_marker" \
    FAKE_SYSTEMCTL_LOG="$systemctl_log" \
    FAKE_CHEZMOI_LOG="$temporary/onboarding-chezmoi.log" \
    "$@" \
    "$script_bin" -qefc "$onboarding_command add-host" "$output"
}

run_onboarding "$onboarding_source" "$onboarding_state" "$temporary/onboarding-new.out"
source_toml="$onboarding_source/.chezmoidata/restic.toml"
[[ $(grep -Fc '[restic.hosts."new-host"]' "$source_toml") -eq 1 ]]
grep -A4 -F '[restic.hosts."new-host"]' "$source_toml" | \
  grep -Fq 'backup_calendar = "*-*-* 03:00:00"'
for action in init backup check 'restore latest'; do
  grep -Fq "$action" "$onboarding_log"
done
test -e "$timer_marker"
test ! -e "$onboarding_source/.chezmoidata/.restic.toml.add-host.lock"
success_record=$(find "$onboarding_state/restic-home/add-host-runs" -name '*.success' -print -quit)
grep -Fxq 'phase=complete' "$success_record"
grep -Fxq 'status=success' "$success_record"
if grep -Eq 'fixture-secret|RESTIC_REPOSITORY|snapshot for new-host|fixture excludes' \
  "$onboarding_state/restic-home/add-host-runs"/*; then
  printf 'add-host diagnostic record exposed non-allowlisted content\n' >&2
  exit 1
fi

rm -f "$timer_marker"
: >"$onboarding_log"
run_onboarding "$onboarding_source" "$onboarding_state" "$temporary/onboarding-resume.out"
[[ $(grep -Fc '[restic.hosts."new-host"]' "$source_toml") -eq 1 ]]
if grep -Fxq init "$onboarding_log"; then
  printf 'existing repository was initialized again\n' >&2
  exit 1
fi
grep -Fq snapshots "$onboarding_log"
grep -Fxq backup "$onboarding_log"
grep -Fxq check "$onboarding_log"

invalid_source="$temporary/onboarding-invalid-source"
invalid_state="$temporary/onboarding-invalid-state"
mkdir -p "$invalid_source/.chezmoidata" "$invalid_state"
cp "$repository/home/.chezmoidata/restic.toml" "$invalid_source/.chezmoidata/restic.toml"
rm -f "$timer_marker"
if run_onboarding "$invalid_source" "$invalid_state" "$temporary/onboarding-invalid.out" \
  FAKE_BACKUP_CALENDAR=invalid; then
  printf 'add-host accepted an invalid systemd calendar\n' >&2
  exit 1
fi
if grep -Fq '[restic.hosts."new-host"]' "$invalid_source/.chezmoidata/restic.toml"; then
  printf 'invalid calendar changed restic.toml\n' >&2
  exit 1
fi
invalid_record=$(find "$invalid_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'error_type=configuration_invalid' "$invalid_record"

conflict_source="$temporary/onboarding-conflict-source"
conflict_state="$temporary/onboarding-conflict-state"
mkdir -p "$conflict_source/.chezmoidata" "$conflict_state"
cp "$repository/home/.chezmoidata/restic.toml" "$conflict_source/.chezmoidata/restic.toml"
if run_onboarding "$conflict_source" "$conflict_state" "$temporary/onboarding-conflict.out" \
  FAKE_SOURCE_CONFLICT=true; then
  printf 'add-host overwrote a concurrent restic.toml change\n' >&2
  exit 1
fi
if grep -Fq '[restic.hosts."new-host"]' "$conflict_source/.chezmoidata/restic.toml"; then
  printf 'source conflict installed a new host entry\n' >&2
  exit 1
fi
conflict_record=$(find "$conflict_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'error_type=source_conflict' "$conflict_record"

lock_source="$temporary/onboarding-lock-source"
lock_state="$temporary/onboarding-lock-state"
mkdir -p "$lock_source/.chezmoidata" "$lock_state"
cp "$repository/home/.chezmoidata/restic.toml" "$lock_source/.chezmoidata/restic.toml"
exec 8<"$lock_source/.chezmoidata"
flock -n 8
if run_onboarding "$lock_source" "$lock_state" "$temporary/onboarding-lock.out"; then
  printf 'add-host ignored another source update holding the transaction lock\n' >&2
  exit 1
fi
exec 8>&-
if grep -Fq '[restic.hosts."new-host"]' "$lock_source/.chezmoidata/restic.toml"; then
  printf 'source lock contention installed a new host entry\n' >&2
  exit 1
fi
lock_record=$(find "$lock_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'error_type=source_conflict' "$lock_record"

exchange_conflict_source="$temporary/onboarding-exchange-conflict-source"
exchange_conflict_state="$temporary/onboarding-exchange-conflict-state"
mkdir -p "$exchange_conflict_source/.chezmoidata" "$exchange_conflict_state"
cp "$repository/home/.chezmoidata/restic.toml" \
  "$exchange_conflict_source/.chezmoidata/restic.toml"
if run_onboarding "$exchange_conflict_source" "$exchange_conflict_state" \
  "$temporary/onboarding-exchange-conflict.out" \
  FAKE_SOURCE_AFTER_COMPARE_CONFLICT=true; then
  printf 'add-host overwrote an unlocked source update after compare\n' >&2
  exit 1
fi
grep -Fxq '# concurrent change after compare' \
  "$exchange_conflict_source/.chezmoidata/restic.toml"
if grep -Fq '[restic.hosts."new-host"]' \
  "$exchange_conflict_source/.chezmoidata/restic.toml"; then
  printf 'post-compare source conflict retained the candidate host entry\n' >&2
  exit 1
fi
exchange_conflict_record=$(find \
  "$exchange_conflict_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'error_type=source_conflict' "$exchange_conflict_record"

disabled_source="$temporary/onboarding-disabled-source"
disabled_state="$temporary/onboarding-disabled-state"
mkdir -p "$disabled_source/.chezmoidata" "$disabled_state"
cp "$repository/home/.chezmoidata/restic.toml" "$disabled_source/.chezmoidata/restic.toml"
printf '\n[restic.hosts."new-host"]\nenabled = false\nbackup_calendar = "*-*-* 03:00:00"\nmaintenance_calendar = "Sun *-*-* 05:00:00"\ncheck_calendar = "*-*-01 07:00:00"\n' \
  >>"$disabled_source/.chezmoidata/restic.toml"
if run_onboarding "$disabled_source" "$disabled_state" "$temporary/onboarding-disabled.out"; then
  printf 'add-host accepted a disabled host entry\n' >&2
  exit 1
fi
disabled_record=$(find "$disabled_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'error_type=host_disabled' "$disabled_record"

apply_source="$temporary/onboarding-apply-source"
apply_state="$temporary/onboarding-apply-state"
mkdir -p "$apply_source/.chezmoidata" "$apply_state"
cp "$repository/home/.chezmoidata/restic.toml" "$apply_source/.chezmoidata/restic.toml"
if run_onboarding "$apply_source" "$apply_state" "$temporary/onboarding-apply-failure.out" \
  FAKE_APPLY_FAIL=true; then
  printf 'add-host ignored an apply failure\n' >&2
  exit 1
fi
grep -Fq '[restic.hosts."new-host"]' "$apply_source/.chezmoidata/restic.toml"
apply_record=$(find "$apply_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'error_type=apply_failed' "$apply_record"

cancel_source="$temporary/onboarding-cancel-source"
cancel_state="$temporary/onboarding-cancel-state"
pending_capture="$temporary/onboarding.pending"
mkdir -p "$cancel_source/.chezmoidata" "$cancel_state"
cp "$repository/home/.chezmoidata/restic.toml" "$cancel_source/.chezmoidata/restic.toml"
if run_onboarding "$cancel_source" "$cancel_state" "$temporary/onboarding-cancel.out" \
  FAKE_GUM_CANCEL=true FAKE_PENDING_CAPTURE="$pending_capture"; then
  printf 'add-host ignored user cancellation\n' >&2
  exit 1
fi
grep -Fxq 'completeness=partial' "$pending_capture"
cancel_record=$(find "$cancel_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'status=cancel' "$cancel_record"
grep -Fxq 'error_type=cancelled' "$cancel_record"

rm -f "$timer_marker" "$repository_marker"
repository_failure_state="$temporary/onboarding-repository-failure-state"
mkdir "$repository_failure_state"
if run_onboarding "$onboarding_source" "$repository_failure_state" \
  "$temporary/onboarding-repository-failure.out" FAKE_INIT_FAIL=true; then
  printf 'add-host ignored repository initialization failure\n' >&2
  exit 1
fi
repository_failure_record=$(find "$repository_failure_state/restic-home/add-host-runs" \
  -name '*.failure' -print -quit)
grep -Fxq 'error_type=repository_unavailable' "$repository_failure_record"
test ! -e "$timer_marker"

: >"$repository_marker"
backup_failure_state="$temporary/onboarding-backup-failure-state"
mkdir "$backup_failure_state"
if run_onboarding "$onboarding_source" "$backup_failure_state" \
  "$temporary/onboarding-backup-failure.out" FAKE_BACKUP_FAIL=true; then
  printf 'add-host ignored backup failure\n' >&2
  exit 1
fi
backup_failure_record=$(find "$backup_failure_state/restic-home/add-host-runs" \
  -name '*.failure' -print -quit)
grep -Fxq 'error_type=backup_failed' "$backup_failure_record"
test ! -e "$timer_marker"

check_failure_state="$temporary/onboarding-check-failure-state"
mkdir "$check_failure_state"
if run_onboarding "$onboarding_source" "$check_failure_state" \
  "$temporary/onboarding-check-failure.out" FAKE_CHECK_FAIL=true; then
  printf 'add-host ignored check failure\n' >&2
  exit 1
fi
check_failure_record=$(find "$check_failure_state/restic-home/add-host-runs" \
  -name '*.failure' -print -quit)
grep -Fxq 'error_type=check_failed' "$check_failure_record"
test ! -e "$timer_marker"

mixed_timer_state="$temporary/onboarding-mixed-timer-state"
mkdir "$mixed_timer_state"
if run_onboarding "$onboarding_source" "$mixed_timer_state" \
  "$temporary/onboarding-mixed-timer.out" FAKE_TIMER_MIXED=true; then
  printf 'add-host accepted mixed timer state\n' >&2
  exit 1
fi
mixed_timer_record=$(find "$mixed_timer_state/restic-home/add-host-runs" \
  -name '*.failure' -print -quit)
grep -Fxq 'error_type=timer_state_invalid' "$mixed_timer_record"

rm -f "$timer_marker"
if run_onboarding "$onboarding_source" "$onboarding_state" "$temporary/onboarding-restore-failure.out" \
  FAKE_RESTORE_MISMATCH=true; then
  printf 'add-host ignored a representative restore mismatch\n' >&2
  exit 1
fi
test ! -e "$timer_marker"
restore_failure_record=$(find "$onboarding_state/restic-home/add-host-runs" \
  -name '*.failure' -print | sort | tail -n 1)
grep -Fxq 'error_type=restore_failed' "$restore_failure_record"

cleanup_failure_state="$temporary/onboarding-cleanup-failure-state"
mkdir "$cleanup_failure_state"
if run_onboarding "$onboarding_source" "$cleanup_failure_state" \
  "$temporary/onboarding-cleanup-failure.out" FAKE_RM_FAIL_RESTORE=true; then
  printf 'add-host ignored temporary restore cleanup failure\n' >&2
  exit 1
fi
test ! -e "$timer_marker"
cleanup_failure_record=$(find "$cleanup_failure_state/restic-home/add-host-runs" \
  -name '*.failure' -print -quit)
grep -Fxq 'error_type=cleanup_failed' "$cleanup_failure_record"

primary_cleanup_failure_state="$temporary/onboarding-primary-cleanup-failure-state"
mkdir "$primary_cleanup_failure_state"
if run_onboarding "$onboarding_source" "$primary_cleanup_failure_state" \
  "$temporary/onboarding-primary-cleanup-failure.out" \
  FAKE_BACKUP_FAIL=true FAKE_RM_FAIL_RESTORE=true; then
  printf 'add-host ignored backup failure combined with cleanup failure\n' >&2
  exit 1
fi
grep -Fq 'temporary Restic output or restored content may remain' \
  "$temporary/onboarding-primary-cleanup-failure.out"
primary_cleanup_record=$(find \
  "$primary_cleanup_failure_state/restic-home/add-host-runs" -name '*.failure' -print -quit)
grep -Fxq 'error_type=backup_failed' "$primary_cleanup_record"

if run_onboarding "$onboarding_source" "$onboarding_state" "$temporary/onboarding-timer-failure.out" \
  FAKE_ENABLE_FAIL=true; then
  printf 'add-host ignored timer activation failure\n' >&2
  exit 1
fi
test ! -e "$timer_marker"
grep -Fq -- '--user disable --now restic-backup.timer restic-maintenance.timer restic-check.timer' \
  "$systemctl_log"

if run_onboarding "$onboarding_source" "$onboarding_state" \
  "$temporary/onboarding-timer-rollback-failure.out" \
  FAKE_ENABLE_FAIL=true FAKE_DISABLE_FAIL=true; then
  printf 'add-host ignored timer rollback failure\n' >&2
  exit 1
fi
test -e "$timer_marker"
timer_rollback_record=$(find "$onboarding_state/restic-home/add-host-runs" \
  -name '*.failure' -print | sort | tail -n 1)
grep -Fxq 'error_type=timer_rollback_failed' "$timer_rollback_record"
rm -f "$timer_marker"

: >"$timer_marker"
recording_off_state="$temporary/onboarding-recording-off"
mkdir "$recording_off_state"
run_onboarding "$onboarding_source" "$recording_off_state" "$temporary/onboarding-recording-off.out" \
  RESTIC_HOME_ADD_HOST_RECORDING=off
if find "$recording_off_state" -type f | grep -q .; then
  printf 'add-host recording opt-out wrote a record\n' >&2
  exit 1
fi

recording_failure_state="$temporary/onboarding-recording-file"
: >"$recording_failure_state"
run_onboarding "$onboarding_source" "$recording_failure_state" \
  "$temporary/onboarding-recording-failure.out"
grep -Fq 'diagnostic recording is unavailable' "$temporary/onboarding-recording-failure.out"

final_record_failure_state="$temporary/onboarding-final-record-failure-state"
mkdir "$final_record_failure_state"
run_onboarding "$onboarding_source" "$final_record_failure_state" \
  "$temporary/onboarding-final-record-failure.out" \
  FAKE_FINAL_RECORD_MOVE_FAIL=true
final_pending_record=$(find "$final_record_failure_state/restic-home/add-host-runs" \
  -name '*.pending' -print -quit)
grep -Fxq 'completeness=partial' "$final_pending_record"
grep -Fq 'diagnostic recording is unavailable' \
  "$temporary/onboarding-final-record-failure.out"

record_dir="$onboarding_state/restic-home/add-host-runs"
for index in $(seq -w 1 25); do : >"$record_dir/00000000T000000Z-$index.success"; done
for index in $(seq -w 1 55); do : >"$record_dir/00000000T000000Z-$index.failure"; done
run_onboarding "$onboarding_source" "$onboarding_state" "$temporary/onboarding-retention.out"
[[ $(find "$record_dir" -name '*.success' | wc -l) -le 20 ]]
[[ $(find "$record_dir" -name '*.failure' | wc -l) -le 50 ]]
if grep -Eq 's3:https://fixture.invalid|fixture-secret-child' \
  "$temporary"/onboarding-*.out "$onboarding_state/restic-home/add-host-runs"/*; then
  printf 'add-host exposed captured Restic output\n' >&2
  exit 1
fi

printf 'Restic home backup tests passed\n'
