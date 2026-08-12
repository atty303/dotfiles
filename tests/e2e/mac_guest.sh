#!/bin/bash

set -euo pipefail

source_directory=$(cd -P -- "$1" && pwd -P)
identity_file=$2
recipient=$3
log_directory=$4
chezmoi=$HOME/.local/bin/chezmoi

exec > >(/usr/bin/tee -a "$log_directory/stdout.log")
exec 2> >(/usr/bin/tee -a "$log_directory/stderr.log" >&2)

export CHEZMOI_AGE_KEY
CHEZMOI_AGE_KEY=$(<"$identity_file")
export CHEZMOI_E2E=1
export CHEZMOI_E2E_RECIPIENT=$recipient
export HEADLESS=1
export PATH="$HOME/.local/bin:$PATH"

echo "step: install mise"
# The pinned base image can contain an older package-managed mise that cannot self-update.
for attempt in 1 2 3; do
  if /usr/bin/curl --retry 3 --retry-all-errors --retry-delay 2 -fsSL https://mise.run | \
    /usr/bin/env MISE_VERSION=v2026.8.3 MISE_INSTALL_PATH="$HOME/.local/bin/mise" /bin/sh
  then
    break
  fi
  if ((attempt == 3)); then
    exit 1
  fi
  sleep $((attempt * 2))
done

echo "step: trust source directory"
"$HOME/.local/bin/mise" trust "$source_directory"

cd "$source_directory"
echo "step: bootstrap with install.sh"
/bin/sh ./install.sh

echo "verify: chezmoi state"
if ! "$chezmoi" --source "$source_directory" verify; then
  "$chezmoi" --source "$source_directory" status
  exit 1
fi
test "$("$chezmoi" --source "$source_directory" execute-template '{{ .roles | toJson }}')" = \
  '["development","desktop"]'

echo "verify: encrypted sentinel"
sentinel=$HOME/.config/chezmoi-e2e/sentinel.txt
test "$(<"$sentinel")" = "chezmoi-e2e-sentinel"
test "$(/usr/bin/stat -f '%Lp' "$sentinel")" = "600"

echo "verify: platform symlinks"
code_settings=$HOME/Library/Application\ Support/Code/User/settings.json
nushell_config=$HOME/Library/Application\ Support/nushell/config.nu
test -L "$code_settings"
test -L "$nushell_config"
test "$(/usr/bin/readlink "$code_settings")" = "$source_directory/home/dot_config/Code/User/managed/settings.json"
test "$(/usr/bin/readlink "$nushell_config")" = "$HOME/.config/nushell/config.nu"

echo "verify: persistent user PATH"
persistent_path=$(plutil -extract PathEnvironmentVariable raw /var/db/com.apple.xpc.launchd/config/user.plist)
case "$persistent_path" in
  "$HOME/.local/bin:"*) ;;
  *) exit 1 ;;
esac

echo "verify: mise packages and tools"
mise -C "$HOME" bootstrap packages status --missing
test "$(mise -C "$HOME" ls --missing --json)" = "{}"

test -x "$HOME/.local/bin/age"
test -x "$HOME/.local/bin/bat"
test -x "$HOME/.local/bin/rg"

echo "verify: idempotence"
test -z "$("$chezmoi" --source "$source_directory" status)"
"$chezmoi" --source "$source_directory" apply --dry-run --verbose
"$chezmoi" --source "$source_directory" apply
"$chezmoi" --source "$source_directory" verify
test -z "$("$chezmoi" --source "$source_directory" status)"
