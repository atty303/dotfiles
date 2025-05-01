# https://docs.atuin.sh/
export-env {
    if (which atuin | is-not-empty) {
        # Install the shell integration
        const init_path = $nu.data-dir | path join vendor autoload atuin.nu
        if ($init_path | path type | $in != "file") {
            ^atuin init nu | save $init_path --force
        }

        # Automatically log in and sync if running in a Cloud Development Environment
        # - CDE_PERSONAL_SECRETS: {"atuin": {"username":"<username>","password":"<password>","key":"<key>"}}
        # Codespaces: https://github.com/settings/codespaces/secrets/new
        # Gitpod: https://app.gitpod.io/settings/secrets
        if (^atuin status) =~ "You are not logged in to a sync server" {
            let secrets = if ($env.CDE_PERSONAL_SECRETS? | is-not-empty) {
                try { $env.CDE_PERSONAL_SECRETS | from json } catch { null }
            } else if ("/usr/local/secrets/CDE_PERSONAL_SECRETS" | path exists) {
                try { open "/usr/local/secrets/CDE_PERSONAL_SECRETS" | from json } catch { null }
            }
            let login = $secrets.atuin?
            if $login != null {
                print -e "✅ Automatically logging in to Atuin and syncing your shell history"
                ^atuin login -u $login.username -p $login.password -k $login.key
                ^atuin sync
            } else {
                print -e "⚠ No CDE_PERSONAL_SECRETS found. Please login manually."
            }
        }
    }
}