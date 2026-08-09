def "nu-complete mise commands" [] {
    ^mise --help
    | lines
    | skip until { $in == "Commands:" }
    | skip 1
    | take until { $in == "" }
    | parse --regex '^\s{2}(?<value>\S+)\s+(?<description>.+)$'
}

def "nu-complete mise tasks" [] {
    ^mise tasks --json
    | from json
    | select name description
    | rename value description
}

def "nu-complete mise usage" [spans: list<string>] {
    let version = ^mise --version | split row " " | first | str replace --all "." "_"
    let spec_dir = ($env.XDG_CACHE_HOME? | default ($nu.home-dir? | default $nu.home-path? | path join ".cache") | path join usage)
    let spec_file = $spec_dir | path join $"usage__usage_spec_mise_($version).spec"

    if not ($spec_file | path exists) {
        mkdir $spec_dir
        ^mise usage | collect | save $spec_file
    }

    ^usage complete-word --file $spec_file --shell nu -- ...$spans
    | lines
    | each {|line|
        $line | split column "\t" | rename value description | into record
    }
}

def mise-completer [spans: list<string>] {
    let args = $spans | skip 1

    if ($args | length) <= 1 {
        nu-complete mise commands | append (nu-complete mise tasks) | uniq-by value
    } else if ($args.0 in [run r watch w]) or ($args | take 2) == [tasks run] {
        nu-complete mise tasks
    } else {
        nu-complete mise usage $spans
    }
}

@complete mise-completer
extern mise []
