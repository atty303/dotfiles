#!/usr/bin/env bash

set -euo pipefail

repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
temporary="$(mktemp -d)"
trap 'rm -rf "$temporary"' EXIT
empty_config="$temporary/empty.toml"
touch "$empty_config"

render_config() {
  local roles=${1-}
  chezmoi execute-template --init --source "$repository" \
    --promptMultichoice "Roles=$roles" <"$repository/home/.chezmoi.toml.tmpl"
}

grep -Fq 'roles = ["development", "desktop", "secrets"]' < <(render_config development/desktop/secrets)
grep -Fq 'roles = ["development", "secrets"]' < <(
  chezmoi execute-template --init --config "$empty_config" --config-format toml \
    --source "$repository" <"$repository/home/.chezmoi.toml.tmpl"
)
grep -Fq 'roles = ["desktop", "gaming"]' < <(
  CHEZMOI_ROLE_DEFAULTS=development,secrets chezmoi execute-template --init --source "$repository" \
    --override-data '{"roles":["desktop","gaming"]}' <"$repository/home/.chezmoi.toml.tmpl"
)
grep -Fq 'roles = []' < <(
  chezmoi execute-template --init --source "$repository" \
    --override-data '{"roles":[]}' <"$repository/home/.chezmoi.toml.tmpl"
)
for roles in unknown development/development desktop/work/work; do
  if render_config "$roles" >"$temporary/rejected" 2>&1; then
    printf 'invalid roles were accepted: %s\n' "$roles" >&2
    exit 1
  fi
done

fake_bin="$temporary/bin"
mkdir -p "$fake_bin"
cat >"$fake_bin/chezmoi" <<'EOF'
#!/bin/sh
if [ -n "${FAKE_CWD_LOG:-}" ]; then
  pwd >"$FAKE_CWD_LOG"
fi
if [ -n "${FAKE_ROLE_DEFAULTS_LOG:-}" ]; then
  printf '%s\n' "${CHEZMOI_ROLE_DEFAULTS:-}" >"$FAKE_ROLE_DEFAULTS_LOG"
fi
printf '%s\n' "$@" >"$FAKE_LOG"
exit "${FAKE_CHEZMOI_STATUS:-0}"
EOF
chmod +x "$fake_bin/chezmoi"

cat >"$fake_bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${FAKE_UNAME:-Linux}"
EOF
chmod +x "$fake_bin/uname"

cat >"$fake_bin/find" <<'EOF'
#!/bin/sh
if [ "${FAKE_DESKTOP_SESSION_DEFINITION:-false}" = true ]; then
  printf '%s\n' /usr/share/wayland-sessions/test.desktop
fi
EOF
chmod +x "$fake_bin/find"
for command in flatpak systemctl xdg-open; do
  cat >"$fake_bin/$command" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$fake_bin/$command"
done

run_install() {
  FAKE_LOG="$1" PATH="$fake_bin:/usr/bin:/bin" /bin/sh "$repository/install.sh" "${@:2}"
}

installer_home="$temporary/installer-home"
mkdir -p "$installer_home"
log="$temporary/installer-cwd.log"
(
  cd "$repository"
  HOME="$installer_home" FAKE_CWD_LOG="$log.cwd" run_install "$log"
)
[[ $(<"$log.cwd") == "$installer_home" ]]

log="$temporary/linux-headless.log"
FAKE_UNAME=Linux CODESPACES=true REMOTE_CONTAINERS_IPC=test \
  XDG_CURRENT_DESKTOP=Test WAYLAND_DISPLAY=wayland-0 run_install "$log" --depth 1
grep -Fxq 'Roles=development/secrets' "$log"
grep -Fxq -- '--depth' "$log"
grep -Fxq '1' "$log"

log="$temporary/linux-desktop.log"
FAKE_UNAME=Linux FAKE_DESKTOP_SESSION_DEFINITION=true run_install "$log"
grep -Fxq 'Roles=development/desktop/secrets' "$log"

log="$temporary/macos.log"
FAKE_UNAME=Darwin run_install "$log"
grep -Fxq 'Roles=development/desktop/secrets' "$log"

log="$temporary/prompt.log"
defaults_log="$temporary/prompt-defaults.log"
FAKE_UNAME=Linux FAKE_DESKTOP_SESSION_DEFINITION=true FAKE_LOG="$log" \
  FAKE_ROLE_DEFAULTS_LOG="$defaults_log" PATH="$fake_bin:/usr/bin:/bin" \
  /bin/sh "$repository/install.sh" --prompt-roles
grep -Fxq 'development,desktop,secrets' "$defaults_log"
if grep -Fxq -- '--no-tty' "$log" || grep -Fq -- '--promptMultichoice' "$log"; then
  printf 'interactive role selection was suppressed by installer arguments\n' >&2
  exit 1
fi

desktop_data='{"roles":["desktop"],"chezmoi":{"osRelease":{"id":"bazzite","idLike":"fedora"}}}'
fedora_desktop_data='{"roles":["desktop"],"chezmoi":{"osRelease":{"id":"fedora","idLike":""}}}'
ubuntu_desktop_data='{"roles":["desktop"],"chezmoi":{"osRelease":{"id":"ubuntu","idLike":"debian"}}}'
baseline_data='{"roles":[],"chezmoi":{"osRelease":{"id":"bazzite","idLike":"fedora"}}}'
secrets_data='{"roles":["secrets"]}'
desktop_managed="$(chezmoi managed --source "$repository" --override-data "$desktop_data")"
baseline_managed="$(chezmoi managed --source "$repository" --override-data "$baseline_data")"
grep -Fxq '.config/chrome-web-apps/web-apps.json' <<<"$desktop_managed"
grep -Fxq '.local/bin/open-in-default-browser' <<<"$desktop_managed"
grep -Fxq '.local/share/applications/open-in-default-browser.desktop' <<<"$desktop_managed"
grep -Fxq '.local/bin/chatgpt' <<<"$desktop_managed"
grep -Fxq '.local/libexec/chatgpt-update' <<<"$desktop_managed"
grep -Fxq '.local/share/applications/chatgpt.desktop' <<<"$desktop_managed"
fedora_desktop_managed="$(chezmoi managed --source "$repository" --override-data "$fedora_desktop_data")"
grep -Fxq '.local/bin/chatgpt' <<<"$fedora_desktop_managed"
ubuntu_desktop_managed="$(chezmoi managed --source "$repository" --override-data "$ubuntu_desktop_data")"
if grep -Eq '^\.local/(bin/chatgpt|libexec/chatgpt-update|share/applications/chatgpt\.desktop|share/chatgpt/)' <<<"$ubuntu_desktop_managed"; then
  printf 'Ubuntu desktop render managed Fedora ChatGPT integration\n' >&2
  exit 1
fi
if grep -Eq '^\.config/chrome-web-apps/|^\.local/bin/(chrome-web-app|open-in-default-browser)$|^\.local/share/applications/(chrome-web-app-.*|open-in-default-browser)\.desktop$' <<<"$baseline_managed"; then
  printf 'baseline render managed Chrome web apps\n' >&2
  exit 1
fi
if grep -Eq '^\.local/(bin/chatgpt|libexec/chatgpt-update|share/applications/chatgpt\.desktop|share/chatgpt/)' <<<"$baseline_managed"; then
  printf 'baseline render managed ChatGPT desktop integration\n' >&2
  exit 1
fi
baseline_registration="$temporary/register-baseline.sh"
chezmoi execute-template --source "$repository" --override-data "$baseline_data" \
  <"$repository/home/.chezmoiscripts/linux/run_onchange_after_register-x-open-default.sh.tmpl" \
  >"$baseline_registration"
grep -Fxq 'exit 0' "$baseline_registration"
ubuntu_chatgpt="$temporary/chatgpt-ubuntu.sh"
chezmoi execute-template --source "$repository" --override-data "$ubuntu_desktop_data" \
  <"$repository/home/.chezmoiscripts/linux/run_onchange_after_chatgpt.sh.tmpl" >"$ubuntu_chatgpt"
grep -Fxq 'exit 0' "$ubuntu_chatgpt"
desktop_distrobox="$temporary/distrobox-desktop.sh"
baseline_distrobox="$temporary/distrobox-baseline.sh"
chezmoi execute-template --source "$repository" --override-data "$desktop_data" \
  <"$repository/home/.chezmoiscripts/linux/run_after_distrobox.sh.tmpl" >"$desktop_distrobox"
chezmoi execute-template --source "$repository" --override-data "$baseline_data" \
  <"$repository/home/.chezmoiscripts/linux/run_after_distrobox.sh.tmpl" >"$baseline_distrobox"
grep -Fq '  "noctalia"' "$desktop_distrobox"
grep -Fq '  "scroll"' "$desktop_distrobox"
if grep -Fq '  "dms"' "$desktop_distrobox"; then
  printf 'desktop render selected DMS for Distrobox management\n' >&2
  exit 1
fi
if grep -Eq '  "(noctalia|scroll)"' "$baseline_distrobox"; then
  printf 'baseline render selected a desktop Distrobox\n' >&2
  exit 1
fi

baseline_winget="$temporary/winget-baseline.ps1"
development_winget="$temporary/winget-development.ps1"
baseline_development_winget="$temporary/winget-development-baseline.ps1"
gaming_winget="$temporary/winget-gaming.ps1"
chezmoi execute-template --source "$repository" --override-data "$baseline_data" \
  <"$repository/home/.chezmoiscripts/windows/run_onchange_after_winget-baseline.ps1.tmpl" >"$baseline_winget"
chezmoi execute-template --source "$repository" --override-data '{"roles":["development"]}' \
  <"$repository/home/.chezmoiscripts/windows/run_onchange_after_winget-development.ps1.tmpl" >"$development_winget"
chezmoi execute-template --source "$repository" --override-data "$baseline_data" \
  <"$repository/home/.chezmoiscripts/windows/run_onchange_after_winget-development.ps1.tmpl" >"$baseline_development_winget"
chezmoi execute-template --source "$repository" --override-data '{"roles":["gaming"]}' \
  <"$repository/home/.chezmoiscripts/windows/run_onchange_after_winget-gaming.ps1.tmpl" >"$gaming_winget"
grep -Fq 'AutoHotkey.AutoHotkey' "$baseline_winget"
grep -Fq 'Docker.DockerDesktop' "$development_winget"
if grep -Fq 'Microsoft.VisualStudio.2022.BuildTools' "$baseline_development_winget"; then
  printf 'baseline render selected development packages\n' >&2
  exit 1
fi
grep -Fq 'Valve.Steam' "$gaming_winget"

for data in "$baseline_data" "$desktop_data"; do
  managed="$(chezmoi managed --source "$repository" --override-data "$data")"
  grep -Fxq '.config/atuin/config.toml' <<<"$managed"
  if grep -Eq '^(\.wakatime\.cfg|\.local/share/atuin/key)$' <<<"$managed"; then
    printf 'non-secrets role rendered encrypted bootstrap artifacts\n' >&2
    exit 1
  fi
done
secrets_managed="$(chezmoi managed --source "$repository" --override-data "$secrets_data")"
grep -Fxq '.wakatime.cfg' <<<"$secrets_managed"
grep -Fxq '.local/share/atuin/key' <<<"$secrets_managed"

set +e
FAKE_CHEZMOI_STATUS=42 run_install "$temporary/failure.log"
result=$?
set -e
[[ $result -eq 42 ]]

bootstrap_bin="$temporary/bootstrap-bin"
mkdir -p "$bootstrap_bin"
cat >"$bootstrap_bin/curl" <<'EOF'
#!/bin/sh
printf '%s\n' 'exit 37'
EOF
chmod +x "$bootstrap_bin/curl"
set +e
HOME="$temporary/bootstrap-home" PATH="$bootstrap_bin:/usr/bin:/bin" \
  /bin/sh "$repository/install.sh" >"$temporary/bootstrap.out" 2>&1
result=$?
set -e
[[ $result -eq 37 ]]

expected_ps_roles="\$roles = 'development,desktop,secrets'"
expected_ps_prompt="'--promptMultichoice'"
expected_ps_role_values="\$roles.Replace(',', '/')"
expected_ps_home="Push-Location \$HOME"
grep -Fq "$expected_ps_roles" "$repository/install.ps1"
grep -Fq -- "$expected_ps_prompt" "$repository/install.ps1"
grep -Fq -- "$expected_ps_role_values" "$repository/install.ps1"
grep -Fq "$expected_ps_home" "$repository/install.ps1"
grep -Fq '[ -t 0 ] && [ -t 2 ]' "$repository/install.sh"
if command -v pwsh >/dev/null 2>&1; then
  pwsh -NoLogo -NoProfile -Command \
    "[void][System.Management.Automation.Language.Parser]::ParseFile('$repository/install.ps1',[ref]\$null,[ref]\$null)"
fi

printf 'Role tests passed\n'
