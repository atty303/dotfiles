# Load order:
# 1. env.nu (deprecated)
# 2. config.nu
# 3. $nu.vendor-autoload-dirs
# 4. $nu.user-autoload-dirs

# ⚠ Doesn't set XDG_CONFIG_HOME !
# The default configuration directories are different across Windows, Mac, and Linux.
# Setting environment variables in the shell works when launching from the shell,
# but GUI applications do not inherit the shell's environment variables,
# causing the configuration directory to differ depending on how the application is launched.
# In chezmoi, files are placed under ~/.config, and symbolic links are created from
# the OS-specific directories to this location to standardize the configuration path.

# Enable homebrew for mise command
if $nu.os-info.name == "linux" and ("/home/linuxbrew/.linuxbrew" | path exists) {
    $env.PATH = ($env.PATH | prepend ["/home/linuxbrew/.linuxbrew/bin" "/home/linuxbrew/.linuxbrew/sbin"])
    $env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
    $env.HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar"
    $env.HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew"
    $env.INFOPATH = (if ($env.INFOPATH? | is-not-empty) { $env.INFOPATH | split row (char esep) } else { [] }) | append "/home/linuxbrew/.linuxbrew/share/info" | str join (char esep)
} else if $nu.os-info.name == "macos" and ("/opt/homebrew" | path exists) {
    $env.PATH = ($env.PATH | prepend ["/opt/homebrew/bin" "/opt/homebrew/sbin"])
    $env.HOMEBREW_PREFIX = "/opt/homebrew"
    $env.HOMEBREW_CELLAR = "/opt/homebrew/Cellar"
    $env.HOMEBREW_REPOSITORY = "/opt/homebrew"
    $env.INFOPATH = (if ($env.INFOPATH? | is-not-empty) { $env.INFOPATH | split row (char esep) } else { [] }) | append "/opt/homebrew/share/info" | str join (char esep)
}

use std/util "path add"
path add "~/.local/bin"
path add { linux: "/var/lib/flatpak/exports/bin" }

def get-editor [] {
  [$env.config.buffer-editor, $env.EDITOR, $env.VISUAL] | where { is-not-empty } | first
}

def bash_quote [s: string] {
  $s | str replace -a "'" "'\"'\"'" | $"'($in)'"
}

# Generate vendor/autoload scripts
const vendor_autoload = $nu.data-dir | path join vendor autoload
mkdir $vendor_autoload

const mise_init_path = $vendor_autoload | path join mise.nu
if (which mise | is-not-empty) {
    ^mise activate nu | save $mise_init_path --force
} else {
    rm -fp $mise_init_path
}

const atuin_init_path = $vendor_autoload | path join atuin.nu
if (which atuin | is-not-empty) {
    ^atuin init --disable-up-arrow nu | str replace -a "get -i" "get -o" | save $atuin_init_path --force
} else {
    rm -fp $atuin_init_path
}

# if (which carapace | is-not-empty) {
#     $env.CARAPACE_BRIDGES = 'zsh,inshellisense'
#     const init_path = $vendor_autoload | path join carapace.nu
#     ^carapace _carapace nushell | save $init_path --force
# }

const starship_init_path = $vendor_autoload | path join starship.nu
if (which starship | is-not-empty) {
    ^starship init nu | save $starship_init_path --force

    $env.config.render_right_prompt_on_last_line = false
    $env.TRANSIENT_PROMPT_COMMAND = {|| ^starship module character }
    $env.TRANSIENT_PROMPT_COMMAND_RIGHT = ""
    $env.STARSHIP_CONFIG = "~/.config/starship.toml" | path expand
} else {
    rm -fp $starship_init_path
}

const zoxide_init_path = $vendor_autoload | path join zoxide.nu
if (which zoxide | is-not-empty) {
    ^zoxide init nushell | save $zoxide_init_path --force
} else {
    rm -fp $zoxide_init_path
}
