# If we are called by envinronment resolver, print the environment variables for parent shell
if ($env.RESOLVING_ENVIRONMENT? == "1") {
    $env | transpose name value | where { not (($in.name in ["config" "ENV_CONVERSIONS"]) or ($in.name | str contains "PROMPT")) } | each { |e|
        let conversion = $env.ENV_CONVERSIONS | get -o $e.name
        let value = if ($conversion | is-not-empty) { $e.value | do $conversion.to_string $e.value } else { $e.value }
        let value = if ($e.name | str upcase) == "PATH" { $e.value | str join (char esep) } else { $value }
        print $"export ($e.name)=(bash_quote ($value | to text))"
    }
    exit 0
}
