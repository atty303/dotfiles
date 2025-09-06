#!/usr/bin/env -S bash -euo pipefail

# Even in headless environments, if the terminal connected via SSH is Alacritty, terminfo is required.
# https://github.com/alacritty/alacritty/blob/master/INSTALL.md#terminfo
if ! infocmp alacritty &>/dev/null; then
  curl -sL https://raw.githubusercontent.com/alacritty/alacritty/refs/heads/master/extra/alacritty.info | tic -xe alacritty,alacritty-direct -
fi
