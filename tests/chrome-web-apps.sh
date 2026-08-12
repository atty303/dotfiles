#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT

test_home="$temporary/home"
fake_bin="$temporary/bin"
mkdir -p "$test_home/.config/chrome-web-apps" "$fake_bin"

policy="$test_home/.config/chrome-web-apps/web-apps.json"
chezmoi cat --source "$repository" --override-data '{"roles":["desktop"]}' \
  ~/.config/chrome-web-apps/web-apps.json >"$policy"
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
  --override-data '{"roles":["desktop"]}' \
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
assert_log_contains "$log" "--user-data-dir=$test_home/.var/app/com.google.Chrome/config/google-chrome-web-apps/x"
assert_log_contains "$log" '--app=https://x.com/'
assert_log_contains "$log" '/etc/opt/chrome/policies/managed/web-apps.json'
if grep -Fq -- '--load-extension=' "$log"; then
  printf 'launcher used an unsupported extension loading flag\n' >&2
  exit 1
fi

manifest="$test_home/.var/app/com.google.Chrome/config/google-chrome-web-apps/x/Default/Web Applications/Manifest Resources/lodlkdfmihgonocnmddehnfgiljnadcf"
mkdir -p "$manifest"
preferences="$test_home/.var/app/com.google.Chrome/config/google-chrome-web-apps/x/Default/Preferences"
printf '{"web_app_install_metrics":{"lodlkdfmihgonocnmddehnfgiljnadcf":{}}}\n' >"$preferences"
log="$temporary/x-registered.log"
run_launcher "$log" x
assert_log_contains "$log" '--app=https://x.com/'
if grep -Fq -- '--app-id=' "$log"; then
  printf 'launcher used a registered app ID instead of the stable URL app mode\n' >&2
  exit 1
fi

log="$temporary/youtube-browser.log"
run_launcher "$log" youtube --browser
assert_log_contains "$log" 'chrome://policy'
assert_log_contains "$log" 'google-chrome-web-apps/youtube'
if grep -Fq -- '--load-extension=' "$log"; then
  printf 'launcher used an unsupported extension loading flag\n' >&2
  exit 1
fi

for arguments in '' 'unknown' 'x --unknown' 'x --browser extra'; do
  if [[ -n $arguments ]]; then
    read -r -a argument_list <<<"$arguments"
    command=("$launcher" "${argument_list[@]}")
  else
    command=("$launcher")
  fi
  if HOME="$test_home" PATH="$fake_bin:$PATH" FAKE_LOG="$temporary/rejected.log" \
    "${command[@]}" >/dev/null 2>&1; then
    printf 'launcher accepted invalid arguments: %s\n' "$arguments" >&2
    exit 1
  fi
done

if HOME="$test_home" PATH="$fake_bin:$PATH" FAKE_LOG="$temporary/missing.log" \
  FAKE_CHROME_MISSING=true "$launcher" x >/dev/null 2>&1; then
  printf 'launcher accepted a missing system Chrome Flatpak\n' >&2
  exit 1
fi

# shellcheck disable=SC2016
deno eval '
await import(Deno.args[0]);
const integration = globalThis.xPwaIntegration;
const cases = [
  ["https://x.com/user/status/123/photo/1", true],
  ["https://mobile.x.com/user/status/123/video/2?ref_src=test", true],
  ["https://x.com/user/status/123", false],
  ["https://example.com/user/status/123/photo/1", false],
];
for (const [url, expected] of cases) {
  if (integration.isMediaUrl(url) !== expected) throw new Error(`media classification failed: ${url}`);
}
for (const url of ["https://x.com/home", "https://help.x.com/", "https://twitter.com/user"]) {
  if (!integration.isInternalUrl(url)) throw new Error(`internal classification failed: ${url}`);
}
for (const url of ["https://t.co/abc", "https://example.com/", "mailto:test@example.com"]) {
  if (integration.isInternalUrl(url)) throw new Error(`external classification failed: ${url}`);
}
const encoded = integration.encodeExternalUrl("https://example.com/path?q=日本語#fragment");
if (!encoded.startsWith("x-open-default:")) throw new Error("custom scheme is missing");
' "$repository/home/dot_config/chrome-web-apps/x-integration/logic.js"

for script in content-script.js service-worker.js; do
  deno eval 'new Function(await Deno.readTextFile(Deno.args[0]));' \
    "$repository/home/dot_config/chrome-web-apps/x-integration/$script"
done

bridge="$temporary/open-in-default-browser"
chezmoi cat --source "$repository" --override-data '{"roles":["desktop"]}' \
  ~/.local/bin/open-in-default-browser >"$bridge"
chmod +x "$bridge"
bash -n "$bridge"

cat >"$fake_bin/xdg-open" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$FAKE_XDG_LOG"
EOF
chmod +x "$fake_bin/xdg-open"

external_url='https://example.com/path?q=%E6%97%A5%E6%9C%AC%E8%AA%9E#fragment'
payload=$(printf '%s' "$external_url" | base64 | tr -- '+/' '-_' | tr -d '=\n')
FAKE_XDG_LOG="$temporary/xdg-open.log" PATH="$fake_bin:$PATH" \
  "$bridge" "x-open-default:$payload"
if [[ $(<"$temporary/xdg-open.log") != "$external_url" ]]; then
  printf 'bridge did not preserve the external URL\n' >&2
  exit 1
fi

for rejected in \
  'https://example.com/' \
  'x-open-default:' \
  'x-open-default:***' \
  'x-open-default:bWFpbHRvOnRlc3RAZXhhbXBsZS5jb20'; do
  if FAKE_XDG_LOG="$temporary/rejected-xdg.log" PATH="$fake_bin:$PATH" \
    "$bridge" "$rejected" >/dev/null 2>&1; then
    printf 'bridge accepted invalid input: %s\n' "$rejected" >&2
    exit 1
  fi
done

desktop="$temporary/open-in-default-browser.desktop"
chezmoi cat --source "$repository" --override-data '{"roles":["desktop"]}' \
  ~/.local/share/applications/open-in-default-browser.desktop \
  >"$desktop"
if command -v desktop-file-validate >/dev/null 2>&1; then
  desktop-file-validate "$desktop"
fi
grep -Fq 'MimeType=x-scheme-handler/x-open-default;' "$desktop"

printf 'Chrome web app tests passed\n'
