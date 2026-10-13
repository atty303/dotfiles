def diagnostic [mode: string, status: string] {
    let comparison = if $mode == "declared" {
        "declaration projection unavailable"
    } else {
        "live database unavailable"
    }
    { comparison: $comparison, database_status: $status } | to toml
}

def main [manifest_path: path, sqlite_reader: path, platform: string] {
    let marker = (open --raw /dev/stdin | str trim)
    let mode = if $marker == "orca-settings-declared" { "declared" } else { "actual" }
    let home = ($env.HOME | path expand)
    let config_home = ($env.XDG_CONFIG_HOME? | default ($home | path join ".config") | path expand)
    let profile_dir = if $platform == "darwin" {
        $home | path join "Library" "Application Support" "orca" "profiles" "local-default"
    } else if $platform == "linux" {
        $config_home | path join "orca" "profiles" "local-default"
    } else {
        return ""
    }
    let database_path = ($profile_dir | path join "profile-state.db")
    if not ($database_path | path exists) {
        return ""
    }

    let source_manifest = (open --raw $manifest_path | from toml)
    let managed_paths = ($source_manifest.managed | columns | sort)
    let null_paths = ($source_manifest.managed_nulls? | default [] | sort)
    let excluded_paths = (
        $source_manifest.excluded
        | each {|entry| $entry | get keys}
        | flatten
        | sort
        | uniq
    )
    let spec = {
        managed_paths: $managed_paths,
        null_paths: $null_paths,
        excluded_paths: $excluded_paths,
    }

    let reader_result = (try {
        let resolved_database = (^realpath $database_path | str trim)
        let resolved_profile = ($resolved_database | path dirname)
        let permission = $"--allow-read=($resolved_profile),($sqlite_reader)"
        let result = (
            $spec
            | to json --raw
            | ^deno run --quiet --no-prompt $permission $sqlite_reader $resolved_database
            | complete
        )
        if $result.exit_code != 0 {
            { status: "reader_failed" }
        } else {
            try { $result.stdout | from json } catch { { status: "reader_failed" } }
        }
    } catch {
        { status: "database_unreadable" }
    })

    if $reader_result.status != "ok" {
        diagnostic $mode $reader_result.status
    } else if $mode == "declared" {
        {
            managed: $source_manifest.managed,
            managed_nulls: $null_paths,
            missing: [],
            unreviewed: {},
        }
        | to toml
    } else {
        $reader_result | reject status | to toml
    }
}
