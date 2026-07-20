$env.config.show_banner = "short"
$env.config.history.file_format = "sqlite"
$env.config.table.mode = 'markdown'
$env.config.datetime_format.table = "%y-%m-%d %I:%M:%S"
$env.config.datetime_format.normal = "%y-%m-%d %I:%M:%S"
$env.config.keybindings ++= [
  # alacritty on windows, Control-h sends Control+Backspace
  { name: user, modifier: control, keycode: Backspace, mode: [emacs], event: { edit: Backspace } },
  { name: user, modifier: alt, keycode: char_b, mode: [emacs],
    event: { edit: MoveBigWordLeft } }
  { name: user, modifier: alt, keycode: char_d, mode: [emacs],
    event: { edit: CutBigWordRight } }
  { name: user, modifier: alt, keycode: char_h, mode: [emacs],
    event: { edit: CutBigWordLeft } }
]
