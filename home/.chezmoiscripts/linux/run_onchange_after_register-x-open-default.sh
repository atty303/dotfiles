#!/usr/bin/env bash

set -euo pipefail

desktop_file=open-in-default-browser.desktop
applications_directory="$HOME/.local/share/applications"

for command in update-desktop-database xdg-mime; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Cannot register x-open-default handler: %s is unavailable.\n' "$command" >&2
    exit 1
  fi
done

update-desktop-database "$applications_directory"
xdg-mime default "$desktop_file" x-scheme-handler/x-open-default

mimeapps_file="${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list"
if ! awk -F= -v expected="$desktop_file" '
  /^\[Default Applications\]$/ { in_defaults = 1; next }
  /^\[/ { in_defaults = 0 }
  in_defaults && $1 == "x-scheme-handler/x-open-default" && $2 == expected { found = 1 }
  END { exit !found }
' "$mimeapps_file"; then
  printf 'Could not register x-open-default handler.\n' >&2
  exit 1
fi
