#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

test_home="$temporary/home"
fake_bin="$temporary/bin"
fake_state="$temporary/gearlever-state"
fake_log="$temporary/commands.log"
curl_log="$temporary/curl.log"
fixture="$temporary/screenpipe.AppImage"
host_library="$temporary/host-libraries/libwayland-client.so.0"
tmpdir="$temporary/tmp"
bash_env="$temporary/bash-env"
preload_link="$test_home/.local/lib/appimage-host/screenpipe/libwayland-client.so.0"
mkdir -p "$test_home" "$fake_bin" "$tmpdir" "$(dirname "$host_library")" \
  "$(dirname "$preload_link")"
: >"$fake_state"
: >"$fake_log"
: >"$curl_log"
printf 'AppImage fixture\n' >"$fixture"
printf 'host wayland client fixture\n' >"$host_library"
ln -s "$host_library" "$preload_link"

cat >"$fake_bin/flatpak" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'flatpak' >>"$FAKE_LOG"
printf ' %q' "$@" >>"$FAKE_LOG"
printf '\n' >>"$FAKE_LOG"

case "${1:-}" in
  info)
    [[ ${FAKE_GEARLEVER_MISSING:-false} != true ]] || exit 1
    [[ ${2:-} == --system && ${3:-} == it.mijorus.gearlever ]] || exit 2
    ;;
  run)
    [[ ${2:-} == it.mijorus.gearlever ]] || exit 2
    shift 2
    case "${1:-}" in
      --list-installed)
        [[ ${FAKE_LIST_FAIL:-false} != true ]] || exit 71
        while IFS=$'\t' read -r desktop_id path manager; do
          [[ -n "$desktop_id" ]] || continue
          [[ -n "$manager" ]] || manager=UpdatesNotAvailable
          printf 'screenpipe   [Not specified]   [%s]   %s   \n' "$manager" "$path"
        done <"$FAKE_STATE"
        ;;
      --integrate)
        [[ ${FAKE_INTEGRATE_FAIL:-false} != true ]] || exit 72
        source=${2:?source AppImage is required}
        destination="$HOME/AppImages/screenpipe.appimage"
        desktop_id=screenpipe.desktop
        if [[ ${FAKE_ALTERNATE_DESKTOP:-false} == true ]]; then
          desktop_id=screenpipe-alternate.desktop
        fi
        desktop="$HOME/.local/share/applications/$desktop_id"
        icon="$HOME/AppImages/.icons/screenpipe.png"
        mkdir -p "$(dirname "$destination")" "$(dirname "$desktop")"
        cp "$source" "$destination"
        chmod +x "$destination"
        [[ ${FAKE_INTEGRATE_PARTIAL_FAIL:-false} != true ]] || exit 75
        mkdir -p "$(dirname "$icon")"
        printf 'icon fixture\n' >"$icon"
        printf '[Desktop Entry]\nType=Application\nName=screenpipe\nTryExec=%s\nExec=env DESKTOPINTEGRATION=1 EXISTING_ENV="keep value" %s --existing-argument "argument value"\nIcon=%s\n' \
          "$destination" "$destination" "$icon" >"$desktop"
        printf '%s\t%s\t\n' "$desktop_id" "$destination" >"$FAKE_STATE"
        ;;
      --set-update-source)
        [[ ${FAKE_SET_SOURCE_FAIL:-false} != true ]] || exit 73
        path=${2:?AppImage path is required}
        [[ ${3:-} == --manager ]] || exit 2
        manager=${4:?update manager is required}
        shift 4
        printf '%s\n' "$@" >"$FAKE_OPTIONS"
        if [[ ${FAKE_SET_SOURCE_NOOP:-false} != true ]]; then
          found=false
          : >"$FAKE_STATE.tmp"
          while IFS=$'\t' read -r desktop_id installed_path installed_manager; do
            [[ -n "$desktop_id" ]] || continue
            if [[ "$installed_path" == "$path" ]]; then
              installed_manager=$manager
              found=true
            fi
            printf '%s\t%s\t%s\n' "$desktop_id" "$installed_path" "$installed_manager" \
              >>"$FAKE_STATE.tmp"
          done <"$FAKE_STATE"
          [[ "$found" == true ]] || exit 1
          mv "$FAKE_STATE.tmp" "$FAKE_STATE"
        fi
        ;;
      --remove)
        [[ ${FAKE_REMOVE_FAIL:-false} != true ]] || exit 74
        path=${2:?AppImage path is required}
        [[ ${3:-} == --yes ]] || exit 2
        while IFS=$'\t' read -r desktop_id installed_path manager; do
          [[ "$installed_path" == "$path" ]] || continue
          desktop="$HOME/.local/share/applications/$desktop_id"
          icon=$(sed -n 's/^Icon=//p' "$desktop" | head -n 1)
          rm -f "$path" "$desktop"
          [[ "$icon" != /* ]] || rm -f "$icon"
        done <"$FAKE_STATE"
        : >"$FAKE_STATE"
        ;;
      *)
        printf 'unexpected Gear Lever command: %q ' "$@" >&2
        printf '\n' >&2
        exit 2
        ;;
    esac
    ;;
  *)
    printf 'unexpected flatpak command: %q ' "$@" >&2
    printf '\n' >&2
    exit 2
    ;;
esac
EOF

cat >"$fake_bin/gio" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'gio' >>"$FAKE_LOG"
printf ' %q' "$@" >>"$FAKE_LOG"
printf '\n' >>"$FAKE_LOG"
[[ ${1:-} == trash && $# == 2 ]] || exit 2
rm -f -- "$2"
EOF

cat >"$fake_bin/mv" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf 'mv' >>"$FAKE_LOG"
printf ' %q' "$@" >>"$FAKE_LOG"
printf '\n' >>"$FAKE_LOG"
exec /usr/bin/mv "$@"
EOF

cat >"$fake_bin/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

for argument in "$@"; do
  if [[ ${FAKE_MKTEMP_SIGNAL:-false} == true && \
    "$argument" == */.screenpipe.desktop.*XXXXXX ]]; then
    temporary_file="$(/usr/bin/mktemp "$@")"
    printf '%s\n' "$temporary_file"
    kill -TERM "$PPID"
    exit 143
  fi
done
exec /usr/bin/mktemp "$@"
EOF

cat >"$fake_bin/chmod" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

for argument in "$@"; do
  if [[ ${FAKE_CHMOD_SIGNAL:-false} == true && \
    "$argument" == */.screenpipe.desktop.* ]]; then
    kill -TERM "$PPID"
    exit 143
  fi
done
exec /usr/bin/chmod "$@"
EOF

cat >"$fake_bin/cp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

operands=()
options=true
for argument in "$@"; do
  if [[ "$options" == true && "$argument" == -- ]]; then
    options=false
  elif [[ "$options" == true && "$argument" == -* ]]; then
    continue
  else
    operands+=("$argument")
  fi
done
if [[ ${FAKE_RESTORE_FAIL:-false} == true && ${#operands[@]} -eq 2 && \
  ${operands[0]} == */preexisting-desktops/* ]]; then
  exit 76
fi
exec /usr/bin/cp "$@"
EOF

cat >"$fake_bin/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

output=""
url=""
while (($#)); do
  case "$1" in
    --output)
      output=$2
      shift 2
      ;;
    https://* | http://*)
      url=$1
      shift
      ;;
    *)
      shift
      ;;
  esac
done
printf '%s\n' "$url" >>"$FAKE_CURL_LOG"
[[ ${FAKE_CURL_FAIL:-false} != true ]] || exit 22
cp "$FAKE_FIXTURE" "$output"
EOF
cat >"$bash_env" <<'EOF'
printf() {
  local last_argument=""
  for last_argument in "$@"; do :; done
  if [[ ${FAKE_PRINTF_FAIL_ON_TAIL:-false} == true && "$last_argument" == TailSentinel ]]; then
    return 77
  fi
  builtin printf "$@"
}
EOF

chmod +x "$fake_bin/flatpak" "$fake_bin/gio" "$fake_bin/mv" "$fake_bin/mktemp" \
  "$fake_bin/chmod" "$fake_bin/cp" "$fake_bin/curl"

render() {
  local data="${1:?override data is required}"
  local destination="${2:?render destination is required}"

  chezmoi execute-template --source "$repository" --override-data "$data" \
    <"$repository/home/.chezmoiscripts/linux/run_after_z_gearlever_appimages.sh.tmpl" \
    >"$destination"
  bash -n "$destination"
}

run_script() {
  HOME="$test_home" \
    XDG_DATA_HOME="${TEST_XDG_DATA_HOME:-$test_home/.local/share}" \
    TMPDIR="$tmpdir" \
    FAKE_STATE="$fake_state" \
    FAKE_LOG="$fake_log" \
    FAKE_CURL_LOG="$curl_log" \
    FAKE_FIXTURE="$fixture" \
    FAKE_OPTIONS="$temporary/update-options" \
    BASH_ENV="$bash_env" \
    PATH="$fake_bin:/usr/bin:/bin" \
    bash -euo pipefail "$1"
}

reset_entry() {
  rm -rf "$test_home/AppImages" "$test_home/.local/share/applications"
  : >"$fake_state"
  : >"$fake_log"
  : >"$curl_log"
  rm -f "$temporary/update-options"
}

expect_failure() {
  local expected_status="${1:?status is required}"
  shift
  set +e
  "$@"
  status=$?
  set -e
  [[ "$status" -eq "$expected_status" ]]
}

desktop_data='{"roles":["desktop"]}'
present_script="$temporary/present.sh"
render "$desktop_data" "$present_script"

run_script "$present_script"
appimage="$test_home/AppImages/screenpipe.appimage"
desktop="$test_home/.local/share/applications/screenpipe.desktop"
[[ -x "$appimage" ]]
grep -Fxq "TryExec=$appimage" "$desktop"
grep -Fxq "Exec=env LD_PRELOAD=$preload_link DESKTOPINTEGRATION=1 EXISTING_ENV=\"keep value\" $appimage --existing-argument \"argument value\"" "$desktop"
grep -Fq "mv -- $test_home/.local/share/applications/.screenpipe.desktop." "$fake_log"
grep -Fq 'flatpak run it.mijorus.gearlever --integrate' "$fake_log"
grep -Fq 'flatpak run it.mijorus.gearlever --set-update-source' "$fake_log"
grep -Fxq 'https://screenpipe.com/api/download?platform=linux' "$curl_log"
grep -Fxq 'url=https://screenpipe.com/api/download?platform=linux' "$temporary/update-options"
grep -Fq $'screenpipe.desktop\t'"$appimage"$'\tStaticFileUpdater' "$fake_state"
[[ -z "$(find "$tmpdir" -mindepth 1 -maxdepth 1 -print -quit)" ]]

: >"$fake_log"
: >"$curl_log"
run_script "$present_script"
if grep -Eq -- '--integrate|^curl ' "$fake_log"; then
  printf 'Idempotent AppImage reconciliation downloaded or integrated the app again\n' >&2
  exit 1
fi
grep -Fq 'flatpak run it.mijorus.gearlever --set-update-source' "$fake_log"
[[ ! -s "$curl_log" ]]
[[ "$(grep -o 'LD_PRELOAD=' "$desktop" | wc -l)" -eq 1 ]]

printf 'TailSentinel\n' >>"$desktop"
cp "$desktop" "$temporary/desktop-before-write-failure"
FAKE_PRINTF_FAIL_ON_TAIL=true expect_failure 1 run_script "$present_script"
cmp "$temporary/desktop-before-write-failure" "$desktop"
[[ -z "$(find "$(dirname "$desktop")" -maxdepth 1 -name '.screenpipe.desktop.*' -print -quit)" ]]

set +e
FAKE_CHMOD_SIGNAL=true run_script "$present_script"
signal_status=$?
set -e
[[ "$signal_status" -ne 0 ]]
cmp "$temporary/desktop-before-write-failure" "$desktop"
[[ -z "$(find "$(dirname "$desktop")" -maxdepth 1 -name '.screenpipe.desktop.*' -print -quit)" ]]

set +e
FAKE_MKTEMP_SIGNAL=true run_script "$present_script"
acquisition_signal_status=$?
set -e
[[ "$acquisition_signal_status" -ne 0 ]]
cmp "$temporary/desktop-before-write-failure" "$desktop"
[[ -z "$(find "$(dirname "$desktop")" -maxdepth 1 -name '.screenpipe.desktop.*' -print -quit)" ]]

sed -i "s#LD_PRELOAD=$preload_link#LD_PRELOAD=/wrong/libwayland-client.so.0#" "$desktop"
run_script "$present_script"
grep -Fxq "Exec=env LD_PRELOAD=$preload_link DESKTOPINTEGRATION=1 EXISTING_ENV=\"keep value\" $appimage --existing-argument \"argument value\"" "$desktop"
[[ "$(grep -o 'LD_PRELOAD=' "$desktop" | wc -l)" -eq 1 ]]

reset_entry
run_script "$present_script"
rm -f "$appimage" "$desktop"
: >"$fake_state"
: >"$fake_log"
: >"$curl_log"
run_script "$present_script"
[[ -x "$appimage" && -f "$desktop" ]]
grep -Fq 'flatpak run it.mijorus.gearlever --integrate' "$fake_log"

reset_entry
rm "$preload_link"
expect_failure 1 run_script "$present_script"
[[ ! -e "$appimage" && ! -e "$desktop" && ! -s "$fake_state" ]]
ln -s "$host_library" "$preload_link"
run_script "$present_script"

absent_data='{"roles":["desktop"],"appimages":{"apps":[{"id":"screenpipe","roles":["desktop"],"arches":["amd64"],"state":"absent","desktop_id":"screenpipe.desktop","download_url":"https://screenpipe.com/api/download?platform=linux","update_manager":"StaticFileUpdater","update_options":{"url":"https://screenpipe.com/api/download?platform=linux"}}]}}'
absent_script="$temporary/absent.sh"
render "$absent_data" "$absent_script"
: >"$fake_log"
run_script "$absent_script"
[[ ! -e "$appimage" && ! -e "$desktop" && ! -s "$fake_state" ]]
grep -Fq 'flatpak run it.mijorus.gearlever --remove' "$fake_log"
if grep -Fq -- '--delete' "$fake_log"; then
  printf 'Absent AppImage reconciliation permanently deleted an entry\n' >&2
  exit 1
fi
: >"$fake_log"
run_script "$absent_script"
if grep -Fq -- '--remove' "$fake_log"; then
  printf 'Already-absent AppImage was removed again\n' >&2
  exit 1
fi

reset_entry
: >"$fake_log"
FAKE_CURL_FAIL=true expect_failure 22 run_script "$present_script"
[[ ! -e "$appimage" && ! -e "$desktop" && ! -s "$fake_state" ]]
[[ -z "$(find "$tmpdir" -mindepth 1 -maxdepth 1 -print -quit)" ]]

reset_entry
FAKE_INTEGRATE_FAIL=true expect_failure 72 run_script "$present_script"
[[ ! -e "$appimage" && ! -e "$desktop" && ! -s "$fake_state" ]]

reset_entry
FAKE_INTEGRATE_PARTIAL_FAIL=true expect_failure 75 run_script "$present_script"
[[ ! -e "$appimage" && ! -e "$desktop" && ! -s "$fake_state" ]]
grep -Fq 'gio trash' "$fake_log"

reset_entry
manual_appimage="$test_home/manual-screenpipe.appimage"
mkdir -p "$(dirname "$desktop")"
printf 'manual AppImage\n' >"$manual_appimage"
printf '[Desktop Entry]\nTryExec=%s\nExec=%s\n' "$manual_appimage" "$manual_appimage" >"$desktop"
FAKE_INTEGRATE_FAIL=true expect_failure 72 run_script "$present_script"
grep -Fxq "TryExec=$manual_appimage" "$desktop"
grep -Fxq 'manual AppImage' "$manual_appimage"

reset_entry
mkdir -p "$test_home/AppImages"
manual_orphan="$test_home/AppImages/manual-screenpipe.appimage"
cp "$fixture" "$manual_orphan"
FAKE_INTEGRATE_FAIL=true expect_failure 72 run_script "$present_script"
cmp "$fixture" "$manual_orphan"

reset_entry
alternate_desktop="$test_home/.local/share/applications/screenpipe-alternate.desktop"
alternate_icon="$test_home/AppImages/.icons/screenpipe.png"
mkdir -p "$(dirname "$alternate_desktop")" "$(dirname "$alternate_icon")"
printf 'preexisting icon\n' >"$alternate_icon"
printf '[Desktop Entry]\nName=preexisting\nTryExec=%s\nExec=%s\nIcon=%s\n' \
  "$manual_appimage" "$manual_appimage" "$alternate_icon" >"$alternate_desktop"
cp "$alternate_desktop" "$temporary/alternate-desktop.expected"
cp "$alternate_icon" "$temporary/alternate-icon.expected"
FAKE_ALTERNATE_DESKTOP=true expect_failure 1 run_script "$present_script"
[[ ! -e "$appimage" && ! -s "$fake_state" ]]
cmp "$temporary/alternate-desktop.expected" "$alternate_desktop"
cmp "$temporary/alternate-icon.expected" "$alternate_icon"
grep -Fq 'flatpak run it.mijorus.gearlever --remove' "$fake_log"

reset_entry
FAKE_SET_SOURCE_FAIL=true expect_failure 73 run_script "$present_script"
[[ ! -e "$appimage" && ! -e "$desktop" && ! -s "$fake_state" ]]
grep -Fq 'flatpak run it.mijorus.gearlever --remove' "$fake_log"

reset_entry
shared_icon="$test_home/AppImages/.icons/screenpipe.png"
shared_desktop="$test_home/.local/share/applications/shared-icon.desktop"
mkdir -p "$(dirname "$shared_icon")" "$(dirname "$shared_desktop")"
printf 'shared preexisting icon\n' >"$shared_icon"
printf '[Desktop Entry]\nName=shared icon owner\nTryExec=%s\nExec=%s\nIcon=%s\n' \
  "$manual_appimage" "$manual_appimage" "$shared_icon" >"$shared_desktop"
cp "$shared_icon" "$temporary/shared-icon.expected"
FAKE_SET_SOURCE_FAIL=true expect_failure 73 run_script "$present_script"
[[ ! -e "$appimage" && ! -e "$desktop" && -f "$shared_desktop" && ! -s "$fake_state" ]]
cmp "$temporary/shared-icon.expected" "$shared_icon"

reset_entry
mkdir -p "$(dirname "$desktop")"
printf '[Desktop Entry]\nName=preexisting\nTryExec=%s\nExec=%s\n' \
  "$manual_appimage" "$manual_appimage" >"$desktop"
FAKE_SET_SOURCE_FAIL=true FAKE_RESTORE_FAIL=true expect_failure 1 run_script "$present_script"
[[ ! -e "$appimage" && ! -s "$fake_state" ]]

reset_entry
run_script "$present_script"
FAKE_SET_SOURCE_FAIL=true expect_failure 73 run_script "$present_script"
[[ -e "$appimage" && -e "$desktop" ]]
printf 'screenpipe.desktop\t%s\tUpdatesNotAvailable\n' "$appimage" >"$fake_state"
FAKE_SET_SOURCE_NOOP=true expect_failure 1 run_script "$present_script"
[[ -e "$appimage" && -e "$desktop" ]]

FAKE_REMOVE_FAIL=true expect_failure 74 run_script "$absent_script"
[[ -e "$appimage" && -e "$desktop" ]]

baseline_script="$temporary/baseline.sh"
render '{"roles":[]}' "$baseline_script"
: >"$fake_log"
run_script "$baseline_script"
[[ ! -s "$fake_log" ]]

arm_data='{"roles":["desktop"],"appimages":{"apps":[{"id":"screenpipe","roles":["desktop"],"arches":["arm64"],"state":"present","desktop_id":"screenpipe.desktop","download_url":"https://screenpipe.com/api/download?platform=linux","update_manager":"StaticFileUpdater","update_options":{"url":"https://screenpipe.com/api/download?platform=linux"}}]}}'
arm_script="$temporary/arm.sh"
render "$arm_data" "$arm_script"
: >"$fake_log"
run_script "$arm_script"
[[ ! -s "$fake_log" ]]

reset_entry
TEST_XDG_DATA_HOME="$test_home/custom-share" run_script "$present_script"
[[ -x "$appimage" && -f "$desktop" ]]
[[ ! -e "$test_home/custom-share/applications/screenpipe.desktop" ]]

: >"$fake_log"
PATH="$temporary/no-flatpak" HOME="$test_home" /usr/bin/bash "$present_script"
[[ ! -s "$fake_log" ]]

: >"$fake_log"
: >"$curl_log"
FAKE_GEARLEVER_MISSING=true expect_failure 1 run_script "$present_script"
[[ ! -s "$curl_log" ]]

invalid_state_data='{"roles":["desktop"],"appimages":{"apps":[{"id":"screenpipe","roles":["desktop"],"arches":["amd64"],"state":"broken","desktop_id":"screenpipe.desktop","download_url":"https://screenpipe.com/api/download?platform=linux","update_manager":"StaticFileUpdater","update_options":{"url":"https://screenpipe.com/api/download?platform=linux"}}]}}'
invalid_state_script="$temporary/invalid-state.sh"
render "$invalid_state_data" "$invalid_state_script"
expect_failure 1 run_script "$invalid_state_script"

http_data='{"roles":["desktop"],"appimages":{"apps":[{"id":"screenpipe","roles":["desktop"],"arches":["amd64"],"state":"present","desktop_id":"screenpipe.desktop","download_url":"http://screenpipe.invalid/screenpipe.AppImage","update_manager":"StaticFileUpdater","update_options":{"url":"https://screenpipe.com/api/download?platform=linux"}}]}}'
http_script="$temporary/http.sh"
render "$http_data" "$http_script"
expect_failure 1 run_script "$http_script"

http_update_data='{"roles":["desktop"],"appimages":{"apps":[{"id":"screenpipe","roles":["desktop"],"arches":["amd64"],"state":"present","desktop_id":"screenpipe.desktop","download_url":"https://screenpipe.com/api/download?platform=linux","update_manager":"StaticFileUpdater","update_options":{"url":"http://screenpipe.invalid/screenpipe.AppImage"}}]}}'
http_update_script="$temporary/http-update.sh"
render "$http_update_data" "$http_update_script"
reset_entry
expect_failure 1 run_script "$http_update_script"
[[ ! -e "$appimage" && ! -e "$desktop" && ! -s "$fake_state" && ! -s "$curl_log" ]]
if grep -Eq -- '--integrate|--set-update-source' "$fake_log"; then
  printf 'Invalid update URL changed Gear Lever state\n' >&2
  exit 1
fi

isolated_config="$temporary/nonexistent-chezmoi-config.toml"
source_test_home="$temporary/source-home"
managed_autostart="$source_test_home/.config/autostart/screenpipe-chezmoi.desktop"
legacy_autostart="$source_test_home/.config/autostart/screenpipe.desktop"
managed_preload="$source_test_home/.local/lib/appimage-host/screenpipe/libwayland-client.so.0"
mkdir -p "$(dirname "$managed_autostart")" "$(dirname "$managed_preload")"
resolved_preload="$(
  HOME="$source_test_home" chezmoi --config "$isolated_config" --source "$repository" \
    --destination "$source_test_home" cat --override-data "$desktop_data" "$managed_preload"
)"
[[ -f "$resolved_preload" ]]

apply_conditional_sources() {
  local data="${1:?override data is required}"

  HOME="$source_test_home" chezmoi --config "$isolated_config" --source "$repository" \
    --destination "$source_test_home" apply --override-data "$data" \
    "$(dirname "$managed_autostart")" "$(dirname "$managed_preload")"
}

printf '[Desktop Entry]\nType=Application\nVersion=1.0\nName=screenpipe\nComment=screenpipe startup script managed by chezmoi\nExec=env LD_PRELOAD=%s %s/AppImages/screenpipe.appimage --autostart\nStartupNotify=false\nTerminal=false\n' \
  "$managed_preload" "$source_test_home" >"$managed_autostart"
printf 'legacy screenpipe autostart\n' >"$legacy_autostart"
apply_conditional_sources "$desktop_data"
[[ ! -e "$managed_autostart" && -L "$managed_preload" && ! -e "$legacy_autostart" ]]

for disabled_data in \
  '{"roles":[]}' \
  '{"roles":["desktop"],"appimages":{"apps":[{"id":"screenpipe","roles":["desktop"],"arches":["amd64"],"state":"absent"}]}}' \
  '{"roles":["desktop"],"appimages":{"apps":[{"id":"screenpipe","roles":["desktop"],"arches":["arm64"],"state":"present"}]}}'
do
  apply_conditional_sources "$desktop_data"
  [[ ! -e "$managed_autostart" && -L "$managed_preload" ]]
  apply_conditional_sources "$disabled_data"
  if [[ -e "$managed_autostart" || -L "$managed_preload" ]]; then
    printf 'Conditional screenpipe sources survived an inapplicable transition: %s\n' \
      "$disabled_data" >&2
    exit 1
  fi
done

printf 'Gear Lever AppImage lifecycle tests passed\n'
