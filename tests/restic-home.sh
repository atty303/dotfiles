#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

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
for disabled_data in "$nonsecret_data" "$unknown_data"; do
  if chezmoi --config "$chezmoi_config" managed --source "$repository" \
    --override-data "$disabled_data" |
    grep -Eq '^\.local/bin/restic-home$|^\.config/systemd/user/restic-'; then
    printf 'disabled host or role managed restic automation\n' >&2
    exit 1
  fi
done

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
test -f "$transition_home/.config/restic/b2.env"
test ! -e "$transition_home/.config/restic/credentials"
test ! -e "$transition_home/.config/restic/passwords"
if find "$transition_home" \( -type f -o -type l \) \
  ! -path "$transition_home/.local/bin/restic-archive" \
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

printf 'Restic home backup tests passed\n'
