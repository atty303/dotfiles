local wezterm = require 'wezterm'
local config = {}

config.font = wezterm.font("UDEV Gothic NFLG")
config.font_size = 12.0
config.color_scheme = "Dracula"
config.window_decorations = "RESIZE|INTEGRATED_BUTTONS"
config.tab_max_width = 32

config.window_padding = {
  left = '0.5cell',
  right = '0.5cell',
  top = '0.5cell',
  bottom = '0.5cell',
}

config.window_background_opacity = 0.8
config.text_background_opacity = 1
config.win32_system_backdrop = "Disable"

config.default_prog = { 'nu', '-l' }

return config
