$env.SHELL = $nu.current-exe
$env.PAGER = "bat"
$env.MANPAGER = "bat -plman"
$env.EDITOR = "hx"
$env.SRC_ROOT = (if $nu.os-info.name == "windows" { "D:/src" } else { "~/src" }) | path expand
$env.LS_COLORS = (vivid generate catppuccin-mocha)
$env.RUSTUP_HOME = "~/.local/share/rustup" | path expand
$env.FZF_DEFAULT_OPTS_FILE = "~/.config/fzfrc" | path expand
