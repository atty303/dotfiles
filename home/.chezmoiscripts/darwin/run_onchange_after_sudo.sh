#!/usr/bin/env -S bash -euo pipefail

user_path="$HOME/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/opt/homebrew/sbin"

sudo launchctl config user path "$user_path"
