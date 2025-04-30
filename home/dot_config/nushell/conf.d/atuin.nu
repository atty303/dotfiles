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
        if (^atuin status) =~ "You are not logged in to a sync server" {
            let login = if ($env.ATUIN_LOGIN? | is-not-empty) {
                 # Gitpod quote string
                 if $env.ATUIN_LOGIN =~ "^'.*'$" {
                    $env.ATUIN_LOGIN | str replace -r "^'(.*)'$" "${1}" | from json
                } else {
                    $env.ATUIN_LOGIN | from json
                }
            }
            if $login != null {
                print -e "✅ Automatically logging in to Atuin and syncing your shell history"
                ^atuin login -u $login.username -p $login.password -k $login.key
                ^atuin sync
            } else {
                print -e "⚠ No ATUIN_LOGIN environment variable found. Please login manually."
            }
        }
    }
}