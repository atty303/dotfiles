#!/usr/bin/env -S bash -euo pipefail
# Initialization required for scripts executed by chezmoi apply

if ! [ -x "$(command -v mise)" ]; then
  curl -sL https://mise.run | sh
fi
