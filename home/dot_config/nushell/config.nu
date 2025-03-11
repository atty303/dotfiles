# Load order:
# 1. env.nu (deprecated)
# 2. config.nu
# 3. $nu.vendor-autoload-dirs
# 4. $nu.user-autoload-dirs

$env.XDG_CONFIG_HOME = $"('~/.config' | path expand)"
$env.EDITOR = "hx"

$env.config.show_banner = "short"
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

if $nu.os-info.name == "linux" {
    $env.PATH = ($env.PATH | append ["/home/linuxbrew/.linuxbrew/bin" "/home/linuxbrew/.linuxbrew/sbin"])
    $env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
    $env.HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar"
    $env.HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew"
    $env.INFOPATH = ($env.INFOPATH | split row (char esep) | append "/home/linuxbrew/.linuxbrew/share/info")
}

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

# Generate vendor/autoload scripts
const vendor_autoload = $nu.data-dir | path join vendor autoload
mkdir $vendor_autoload

if (which atuin | is-not-empty) {
    const init_path = $vendor_autoload | path join atuin.nu
    if ($init_path | path type | $in != "file") {
        ^atuin init nu | save $init_path --force
    }
}

if (which carapace | is-not-empty) {
    $env.CARAPACE_BRIDGES = 'zsh,inshellisense'

    const init_path = $vendor_autoload | path join carapace.nu
    if ($init_path | path type | $in != "file") {
        ^carapace _carapace nushell | save $init_path --force
    }
}

if (which mise | is-not-empty) {
    const init_path = $vendor_autoload | path join mise.nu
    ^mise activate nu | lines | filter {$in !~ ^set,Path,} | to text | save $init_path --force
}

if (which starship | is-not-empty) {
    const init_path = $vendor_autoload | path join starship.nu
    if ($init_path | path type | $in != "file") {
        ^starship init nu | save $init_path --force
    }
    $env.config.render_right_prompt_on_last_line = false
    $env.TRANSIENT_PROMPT_COMMAND = {|| ^starship module character }
    $env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
    $env.STARSHIP_CONFIG = "~/.config/starship.toml" | path expand
}

#if $env.ZELLIJ? != "0" {
#  zellij attach -c
#  exit
#}
