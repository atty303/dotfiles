#!/usr/bin/env nu

# https://github.com/alacritty/alacritty/blob/master/INSTALL.md#terminfo
# This script ensures that the terminfo for Alacritty is installed
if (infocmp alacritty | complete | $in.exit_code != 0) {
  http get https://raw.githubusercontent.com/alacritty/alacritty/refs/heads/master/extra/alacritty.info | tic -xe alacritty,alacritty-direct -
}
