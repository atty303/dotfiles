if $nu.os-info.name == "linux" {
    $env.PATH = ($env.PATH | prepend ["/home/linuxbrew/.linuxbrew/bin" "/home/linuxbrew/.linuxbrew/sbin"])
    $env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
    $env.HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar"
    $env.HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew"
    $env.INFOPATH = (if ($env.INFOPATH? | is-not-empty) { $env.INFOPATH | split row (char esep) } else { [] }) | append "/home/linuxbrew/.linuxbrew/share/info" | str join (char esep)
} else if $nu.os-info.name == "macos" {
    $env.PATH = ($env.PATH | prepend ["/opt/homebrew/bin" "/opt/homebrew/sbin"])
    $env.HOMEBREW_PREFIX = "/opt/homebrew"
    $env.HOMEBREW_CELLAR = "/opt/homebrew/Cellar"
    $env.HOMEBREW_REPOSITORY = "/opt/homebrew"
    $env.INFOPATH = (if ($env.INFOPATH? | is-not-empty) { $env.INFOPATH | split row (char esep) } else { [] }) | append "/opt/homebrew/share/info" | str join (char esep)
}
