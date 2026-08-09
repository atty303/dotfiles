def carapace-completer [spans: list<string>] {
    CARAPACE_LENIENT=1 ^carapace $spans.0 nushell ...$spans | from json
}

@complete carapace-completer
extern deno []

@complete carapace-completer
extern chezmoi []
