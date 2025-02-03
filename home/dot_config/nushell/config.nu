$env.XDG_CONFIG_HOME = $"('~/.config' | path expand)"
$env.EDITOR = "hx"

$env.config.show_banner = false
$env.config.history.file_format = "sqlite"
$env.config.table.header_on_separator = true
$env.config.datetime_format.table = "%y-%m-%d %I:%M:%S"
$env.config.datetime_format.normal = "%y-%m-%d %I:%M:%S"
$env.config.keybindings ++= [
  { name: user, modifier: alt, keycode: char_b, mode: [emacs],
    event: { edit: MoveBigWordLeft } }
  { name: user, modifier: alt, keycode: char_d, mode: [emacs],
    event: { edit: CutBigWordRight } }
  { name: user, modifier: alt, keycode: char_h, mode: [emacs],
    event: { edit: CutBigWordLeft } }
]

$env.CARAPACE_BRIDGES = 'zsh,inshellisense'
mkdir ~/.cache/carapace
carapace _carapace nushell | save --force ~/.cache/carapace/init.nu
source ~/.cache/carapace/init.nu

use std/dirs

alias ch = chezmoi
alias che = chezmoi --watch --apply
alias vi = hx

def get-editor [] {
  [$env.config.buffer-editor, $env.EDITOR, $env.VISUAL] | filter { is-not-empty } | first
}

# def chezmoi-edit-apply[name?: path]: nothing -> any {
#   let editor = if name | is-empty { }  $"(get-editor) "
#   let args = [-c $'nu -c "watch \"(chezmoi source-path)\" {|| chezmoi apply --no-tty}" & apply=$! ; hx . ; kill $apply']
#   run-external sh ...$args
# }

source conf.d/index.nu

#if $env.ZELLIJ? != "0" {
#  zellij attach -c
#  exit
#}
