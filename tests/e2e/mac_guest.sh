#!/bin/bash

set -euo pipefail

source_directory=$1
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

cd "$source_directory"
./install.sh

"$chezmoi" --source "$source_directory" verify

sentinel=$HOME/.config/chezmoi-e2e/private_sentinel.txt
test "$(<"$sentinel")" = "chezmoi-e2e-sentinel"
test "$(/usr/bin/stat -f '%Lp' "$sentinel")" = "600"

code_settings=$HOME/Library/Application\ Support/Code/User/settings.json
nushell_config=$HOME/Library/Application\ Support/nushell/config.nu
test -L "$code_settings"
test -L "$nushell_config"
test "$(/usr/bin/readlink "$code_settings")" = "$source_directory/home/dot_config/Code/User/managed/settings.json"
test "$(/usr/bin/readlink "$nushell_config")" = "$HOME/.config/nushell/config.nu"

mise bootstrap packages status --missing
test "$(mise ls --missing --json)" = "{}"

test -x "$HOME/.local/bin/age"
test -x "$HOME/.local/bin/bat"
test -x "$HOME/.local/bin/rg"

test -z "$("$chezmoi" --source "$source_directory" status)"
"$chezmoi" --source "$source_directory" apply --dry-run --verbose
"$chezmoi" --source "$source_directory" apply
"$chezmoi" --source "$source_directory" verify
test -z "$("$chezmoi" --source "$source_directory" status)"
