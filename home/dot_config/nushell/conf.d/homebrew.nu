if $nu.os-info.name == "linux" {
    $env.PATH = ($env.PATH | append ["/home/linuxbrew/.linuxbrew/bin" "/home/linuxbrew/.linuxbrew/sbin"])
    $env.HOMEBREW_PREFIX = "/home/linuxbrew/.linuxbrew"
    $env.HOMEBREW_CELLAR = "/home/linuxbrew/.linuxbrew/Cellar"
    $env.HOMEBREW_REPOSITORY = "/home/linuxbrew/.linuxbrew/Homebrew"
    $env.INFOPATH = (if ($env.INFOPATH? | is-not-empty) { $env.INFOPATH | split row (char esep) } else { [] }) | append "/home/linuxbrew/.linuxbrew/share/info" | str join (char esep)
}
