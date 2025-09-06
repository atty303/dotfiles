# Load order:
# 1. env.nu (deprecated)
# 2. config.nu
# 3. $nu.vendor-autoload-dirs
# 4. $nu.user-autoload-dirs

const pathes = [
    "~/.local/bin"
    "/var/lib/flatpak/exports/bin"
]
$pathes | each { |p|
    if ($p | path exists) {
        $env.PATH = $env.PATH | prepend ($p | path expand)
    }
}

# ⚠ Doesn't set XDG_CONFIG_HOME !
# The default configuration directories are different across Windows, Mac, and Linux.
# Setting environment variables in the shell works when launching from the shell,
# but GUI applications do not inherit the shell's environment variables,
# causing the configuration directory to differ depending on how the application is launched.
# In chezmoi, files are placed under ~/.config, and symbolic links are created from
# the OS-specific directories to this location to standardize the configuration path.

$env.EDITOR = "hx"
$env.SRC_ROOT = (if $nu.os-info.name == "windows" { "D:/src" } else { "~/src" }) | path expand

$env.config.show_banner = "short"
$env.config.history.file_format = "sqlite"
$env.config.table.header_on_separator = true
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

source conf.d/homebrew.nu
source conf.d/ssh-agent.nu

use std *

alias ch = chezmoi
alias che = chezmoi --watch --apply
alias vi = hx
alias r = mise run

def get-editor [] {
  [$env.config.buffer-editor, $env.EDITOR, $env.VISUAL] | where { is-not-empty } | first
}

def bash_quote [s: string] {
  $s | str replace -a "'" "'\"'\"'" | $"'($in)'"
}

# def chezmoi-edit-apply[name?: path]: nothing -> any {
#   let editor = if name | is-empty { }  $"(get-editor) "
#   let args = [-c $'nu -c "watch \"(chezmoi source-path)\" {|| chezmoi apply --no-tty}" & apply=$! ; hx . ; kill $apply']
#   run-external sh ...$args
# }

# Generate vendor/autoload scripts
const vendor_autoload = $nu.data-dir | path join vendor autoload
mkdir $vendor_autoload

if (which carapace | is-not-empty) {
    $env.CARAPACE_BRIDGES = 'zsh,inshellisense'

    const init_path = $vendor_autoload | path join carapace.nu
    ^carapace _carapace nushell | save $init_path --force
}

if (which mise | is-not-empty) {
    const init_path = $vendor_autoload | path join mise.nu
    ^mise activate nu | save $init_path --force
}

if (which starship | is-not-empty) {
    const init_path = $vendor_autoload | path join starship.nu
    ^starship init nu | save $init_path --force

    $env.config.render_right_prompt_on_last_line = false
    $env.TRANSIENT_PROMPT_COMMAND = {|| ^starship module character }
    $env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
    $env.STARSHIP_CONFIG = "~/.config/starship.toml" | path expand
}

if (which zoxide | is-not-empty) {
    const init_path = $vendor_autoload | path join zoxide.nu
    ^zoxide init nushell | save $init_path --force
}

if (which broot | is-not-empty) {
    const init_path = $vendor_autoload | path join broot.nu
    ^broot --print-shell-function nushell | save $init_path --force
}

use conf.d/gh.nu *
use conf.d/atuin.nu *

alias c = br

#if $env.ZELLIJ? != "0" {
#  zellij attach -c
#  exit
#}

# If we are called by envinronment resolver, print the environment variables for parent shell
if ($env.RESOLVING_ENVIRONMENT? == "1") {
    $env | transpose name value | where { not (($in.name in ["config" "ENV_CONVERSIONS"]) or ($in.name | str contains "PROMPT")) } | each { |e|
        let conversion = $env.ENV_CONVERSIONS | get -o $e.name
        let value = if ($conversion | is-not-empty) { $e.value | do $conversion.to_string $e.value } else { $e.value }
        print $"export ($e.name)=(bash_quote ($value | to text))"
    }
    exit 0
}
