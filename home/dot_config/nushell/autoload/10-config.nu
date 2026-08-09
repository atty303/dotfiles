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

def fzf-filter-completions [completions: list<record>, query: string] {
  if ($query | is-empty) or (which fzf | is-empty) {
    return $completions
  }

  let input = (
    $completions
    | enumerate
    | each {|row| { index: $row.index, value: ($row.item.value | to nuon) } }
    | to tsv --noheaders
  )
  let result = do {
    hide-env --ignore-errors __NU_COMPLETION_BASE
    $input | ^fzf --delimiter "\t" --nth 2 --filter $query | complete
  }
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

def completion-candidates [buffer: string] {
  let command_completions = $buffer | commandline complete --detailed
  let complete_arguments = $command_completions | any {|completion| $completion.value == $buffer }
  let buffer_end = $buffer | encode utf-8 | bytes length
  let all_completions = if $complete_arguments {
    $"($buffer) "
    | commandline complete --detailed
    | each {|completion|
        let span = $completion.span
        if $span.start > $buffer_end {
          $completion | merge {
            value: $" ($completion.value)"
            span: { start: $buffer_end, end: $buffer_end }
          }
        } else {
          $completion | merge {
            span: {
              start: $span.start
              end: ([$span.end $buffer_end] | math min)
            }
          }
        }
      }
  } else {
    $command_completions
  }
  if ($all_completions | is-empty) {
    return []
  }

  let literal_completions = (
    $all_completions
    | where {|completion| $completion.value | str starts-with $buffer }
  )
  let described_argument_completions = (
    $all_completions
    | where {|completion|
        $completion.span.start > 0 and $completion.span.end == $buffer_end and ($completion.description? | default null) != null
      }
  )
  let completions = if not ($literal_completions | is-empty) {
    $literal_completions
  } else if not ($described_argument_completions | is-empty) {
    $described_argument_completions
  } else {
    $all_completions
  }

  let span = $completions.0.span
  let query = $buffer | str substring $span.start..<$span.end
  fzf-filter-completions $completions $query
}

def --env menu-completions [buffer: string] {
  let saved_base = $env.__NU_COMPLETION_BASE? | default null
  let saved_query = if $saved_base != null and ($buffer | str starts-with $saved_base) {
    let saved_base_end = $saved_base | encode utf-8 | bytes length
    $buffer | str substring $saved_base_end..
  } else {
    null
  }
  let base_buffer = if $saved_query == null or $saved_query =~ '\s' {
    $env.__NU_COMPLETION_BASE = $buffer
    $buffer
  } else {
    $saved_base
  }
  let base_end = $base_buffer | encode utf-8 | bytes length
  let query = $buffer | str substring $base_end..
  let query_end = $buffer | encode utf-8 | bytes length
  let completions = completion-candidates $base_buffer
  if ($completions | any {|completion| $completion.kind? in [file directory] }) {
    $env.__NU_COMPLETION_BASE = $buffer
    return ($buffer | commandline complete --detailed)
  }
  let filtered_completions = fzf-filter-completions $completions $query

  $filtered_completions | each {|completion|
    $completion | merge {
      span: ($completion.span | merge { end: $query_end })
    }
  }
}

$env.config.show_banner = "short"
$env.config.history.file_format = "sqlite"
$env.config.table.mode = 'markdown'
$env.config.datetime_format.table = "%y-%m-%d %I:%M:%S"
$env.config.datetime_format.normal = "%y-%m-%d %I:%M:%S"
$env.config.completions.algorithm = "prefix"
$env.config.hooks.pre_prompt ++= [{|| hide-env --ignore-errors __NU_COMPLETION_BASE }]
$env.config.hooks.pre_execution ++= [{|| hide-env --ignore-errors __NU_COMPLETION_BASE }]
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
  source: {|buffer, _position| menu-completions $buffer }
  style: {
    text: "#cdd6f4"
    selected_text: { fg: "#b4befe" bg: "#45475a" attr: b }
    description_text: "#cba6f7"
    match_text: { fg: "#f38ba8" attr: u }
    selected_match_text: { fg: "#f38ba8" bg: "#45475a" attr: bu }
  }
}]
$env.config.keybindings ++= [
  {
    name: completion_menu
    modifier: none
    keycode: Tab
    mode: [emacs vi_insert]
    event: {
      until: [
        { send: menunext }
        { send: menu name: completion_menu }
      ]
    }
  }
  # alacritty on windows, Control-h sends Control+Backspace
  { name: user, modifier: control, keycode: Backspace, mode: [emacs], event: { edit: Backspace } },
  { name: user, modifier: alt, keycode: char_b, mode: [emacs], event: { edit: MoveBigWordLeft } }
  { name: user, modifier: alt, keycode: char_d, mode: [emacs], event: { edit: CutBigWordRight } }
  { name: user, modifier: alt, keycode: char_h, mode: [emacs], event: { edit: CutBigWordLeft } }
  { name: help, modifier: alt, keycode: char_?, mode: [emacs], event: { send: executehostcommand, cmd: "temporary-prompt" } }
]
