$env.config.show_banner = false
$env.config.table.header_on_separator = true
$env.config.datetime_format.table = "%y-%m-%d %I:%M:%S"
$env.config.datetime_format.normal = "%y-%m-%d %I:%M:%S"
$env.EDITOR = "hx"

use std/dirs

alias cz = chezmoi

def get-editor [] {
  [$env.config.buffer-editor, $env.EDITOR, $env.VISUAL] | filter { is-not-empty } | first
}

# def chezmoi-edit-apply[name?: path]: nothing -> any {
#   let editor = if name | is-empty { }  $"(get-editor) "
#   let args = [-c $'nu -c "watch \"(chezmoi source-path)\" {|| chezmoi apply --no-tty}" & apply=$! ; hx . ; kill $apply']
#   run-external sh ...$args
# }

source conf.d/index.nu
