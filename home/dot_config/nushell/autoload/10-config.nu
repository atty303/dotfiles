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

def fzf-filter-completions [buffer: string] {
  let completions = $buffer | commandline complete --detailed
  if ($completions | is-empty) {
    return []
  }

  let span = $completions.0.span
  let query = $buffer | str substring $span.start..<$span.end
  if ($query | is-empty) or (which fzf | is-empty) {
    return $completions
  }

  let result = (
    $completions
    | enumerate
    | each {|row| { index: $row.index, value: ($row.item.value | to nuon) } }
    | to tsv --noheaders
    | ^fzf --delimiter "\t" --nth 2 --filter $query
    | complete
  )
  if $result.exit_code == 1 {
    return []
  } else if $result.exit_code != 0 {
    return $completions
  }

  let indices = (
    $result.stdout
    | lines
    | each {|line| $line | split row "\t" | first | into int }
  )

  $indices | each {|index| $completions | get $index }
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
    layout: list
    page_size: 10
    description_position: after
  }
  source: {|buffer, _position| fzf-filter-completions $buffer }
  style: {
    text: "#cdd6f4"
    selected_text: { fg: "#b4befe" bg: "#45475a" attr: b }
    description_text: "#cba6f7"
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
