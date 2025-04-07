local wezterm = require 'wezterm'
local config = {}

config.font = wezterm.font("UDEV Gothic NFLG")
config.font_size = 12.0
config.color_scheme = "Dracula"
config.window_decorations = "RESIZE|INTEGRATED_BUTTONS"

config.window_background_opacity = 0
config.win32_system_backdrop = "Acrylic"

config.default_prog = { 'nu', '-l' }

return config
