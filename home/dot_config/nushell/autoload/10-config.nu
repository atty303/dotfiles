def temporary-prompt [] {
  let proposed = $"(commandline) --help"
  try {
    let temporary = (gum input --prompt "❯ " --prompt.foreground $theme.peach --char-limit 0 --no-show-help --value $proposed)
    if ($temporary | is-not-empty) {
        nu -c $temporary
    }
  } catch {
    ignore
  }
}

$env.config.show_banner = "short"
$env.config.history.file_format = "sqlite"
$env.config.table.mode = 'markdown'
$env.config.datetime_format.table = "%y-%m-%d %I:%M:%S"
$env.config.datetime_format.normal = "%y-%m-%d %I:%M:%S"
$env.config.completions.algorithm = "fuzzy"
$env.config.menus ++= [{
  name: completion_menu
  input_mode: cursor_prefix
  output_mode: suggested_span
  marker: "| "
  type: {
    layout: ide
    min_completion_width: 0
    max_completion_width: 50
    max_completion_height: 10
    padding: 1
    border: true
    cursor_offset: 0
    description_mode: prefer_right
    min_description_width: 15
    max_description_width: 50
    max_description_height: 10
    description_offset: 1
    correct_cursor_pos: true
  }
  style: {
    text: "#cdd6f4"
    selected_text: { fg: "#cdd6f4" bg: "#45475a" attr: b }
    description_text: "#a6adc8"
    match_text: { fg: "#f38ba8" attr: u }
    selected_match_text: { fg: "#f38ba8" bg: "#45475a" attr: bu }
  }
}]
$env.config.keybindings ++= [
  # alacritty on windows, Control-h sends Control+Backspace
  { name: user, modifier: control, keycode: Backspace, mode: [emacs], event: { edit: Backspace } },
  { name: user, modifier: alt, keycode: char_b, mode: [emacs], event: { edit: MoveBigWordLeft } }
  { name: user, modifier: alt, keycode: char_d, mode: [emacs], event: { edit: CutBigWordRight } }
  { name: user, modifier: alt, keycode: char_h, mode: [emacs], event: { edit: CutBigWordLeft } }
  { name: help, modifier: alt, keycode: char_?, mode: [emacs], event: { send: executehostcommand, cmd: "temporary-prompt" } }
]
