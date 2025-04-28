# https://docs.atuin.sh/
export-env {
    if (which atuin | is-not-empty) {
        # Install the shell integration
        const init_path = $nu.data-dir | path join vendor autoload atuin.nu
        if ($init_path | path type | $in != "file") {
            ^atuin init nu | save $init_path --force
        }

        # Automatically log in and sync if running in a Cloud Development Environment
        # - ATUIN_LOGIN: {"username":"<username>","password":"<password>","key":"<key>"}
        # Codespaces: https://github.com/settings/codespaces/secrets/new
        # Gitpod: https://app.gitpod.io/settings/secrets
        if not (null | atuin login | complete | $in.stdout =~ "You are already logged in!") {
            let login = if ($env.ATUIN_LOGIN? | is-not-empty) {
                $env.ATUIN_LOGIN | from json
            }
            if ($login != null) {
                let login = $env.ATUIN_LOGIN | from json
                ^atuin login -u $login.username -p $login.password -k $login.key
                ^atuin sync
            } else {
                print -e "⚠ No ATUIN_LOGIN environment variable found. Please login manually."
            }
        }
    }
}