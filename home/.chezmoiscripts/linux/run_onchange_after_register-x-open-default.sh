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

if [[ $(xdg-mime query default x-scheme-handler/x-open-default) != "$desktop_file" ]]; then
  printf 'Could not register x-open-default handler.\n' >&2
  exit 1
fi
