#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

test_home="$temporary/home"
fake_bin="$temporary/bin"
mkdir -p "$test_home/.config/chrome-web-apps" "$fake_bin"

policy="$test_home/.config/chrome-web-apps/web-apps.json"
chezmoi cat --source "$repository" ~/.config/chrome-web-apps/web-apps.json >"$policy"

deno eval '
const policy = JSON.parse(await Deno.readTextFile(Deno.args[0]));
const expectedKeys = ["BackgroundModeEnabled", "WebAppInstallForceList"];
const actualKeys = Object.keys(policy).sort();
if (JSON.stringify(actualKeys) !== JSON.stringify(expectedKeys)) {
  throw new Error("unexpected policy keys: " + actualKeys.join(", "));
}
if (policy.BackgroundModeEnabled !== false) {
  throw new Error("background mode is not disabled");
}
const expected = new Map([
  ["https://x.com/", "lodlkdfmihgonocnmddehnfgiljnadcf"],
  ["https://www.youtube.com/", "agimnkijcaahngcdmfeangaknmldooml"],
]);
if (policy.WebAppInstallForceList.length !== expected.size) {
  throw new Error("unexpected web app count");
}
for (const app of policy.WebAppInstallForceList) {
  if (!expected.has(app.url)) throw new Error("unexpected web app: " + app.url);
  if (app.default_launch_container !== "window") throw new Error("web app is not windowed");
  if (app.create_desktop_shortcut !== false) throw new Error("desktop shortcut is enabled");
}
for (const forbidden of ["ExtensionSettings", "NotificationsAllowedForUrls", "BrowserSignin", "SyncDisabled"]) {
  if (forbidden in policy) throw new Error("unexpected policy: " + forbidden);
}
' "$policy"

launcher="$temporary/chrome-web-app"
chezmoi execute-template --source "$repository" \
  <"$repository/home/dot_local/bin/executable_chrome-web-app.tmpl" \
  >"$launcher"
chmod +x "$launcher"
bash -n "$launcher"

cat >"$fake_bin/flatpak" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == info ]]; then
  [[ $* == "info --system com.google.Chrome" ]]
  [[ ${FAKE_CHROME_MISSING:-false} != true ]]
  exit
fi

printf 'flatpak' >"$FAKE_LOG"
printf ' %q' "$@" >>"$FAKE_LOG"
printf '\n' >>"$FAKE_LOG"
EOF
chmod +x "$fake_bin/flatpak"

run_launcher() {
  HOME="$test_home" PATH="$fake_bin:$PATH" FAKE_LOG="$1" "$launcher" "${@:2}"
}

assert_log_contains() {
  local log=${1:?log is required}
  local expected=${2:?expected text is required}
  grep -Fq -- "$expected" "$log"
}

log="$temporary/x-url.log"
run_launcher "$log" x
assert_log_contains "$log" 'run --system'
assert_log_contains "$log" '--filesystem='
assert_log_contains "$log" '--command=/usr/bin/bash'
assert_log_contains "$log" '--user-data-dir=/tmp/'
assert_log_contains "$log" '--app=https://x.com/'
assert_log_contains "$log" '/etc/opt/chrome/policies/managed/web-apps.json'

manifest="$test_home/.var/app/com.google.Chrome/config/google-chrome-web-apps/x/Default/Web Applications/Manifest Resources/lodlkdfmihgonocnmddehnfgiljnadcf"
mkdir -p "$manifest"
log="$temporary/x-app-id.log"
run_launcher "$log" x
assert_log_contains "$log" '--app-id=lodlkdfmihgonocnmddehnfgiljnadcf'
if grep -Fq -- '--app=https://x.com/' "$log"; then
  printf 'launcher used the URL after the target manifest became ready\n' >&2
  exit 1
fi

log="$temporary/youtube-browser.log"
run_launcher "$log" youtube --browser
assert_log_contains "$log" 'chrome://policy'
assert_log_contains "$log" 'google-chrome-web-apps/youtube'

for arguments in '' 'unknown' 'x --unknown' 'x --browser extra'; do
  read -r -a argument_list <<<"$arguments"
  if HOME="$test_home" PATH="$fake_bin:$PATH" FAKE_LOG="$temporary/rejected.log" \
    "$launcher" "${argument_list[@]}" >/dev/null 2>&1; then
    printf 'launcher accepted invalid arguments: %s\n' "$arguments" >&2
    exit 1
  fi
done

if HOME="$test_home" PATH="$fake_bin:$PATH" FAKE_LOG="$temporary/missing.log" \
  FAKE_CHROME_MISSING=true "$launcher" x >/dev/null 2>&1; then
  printf 'launcher accepted a missing system Chrome Flatpak\n' >&2
  exit 1
fi

printf 'Chrome web app tests passed\n'
