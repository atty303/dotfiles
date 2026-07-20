alias ch = chezmoi
alias che = chezmoi --watch --apply
alias cha = chezmoi apply
alias vi = hx
alias r = mise run
alias jf = jj git fetch
alias e = explore

def --env y [...args] {
	let tmp = (mktemp -t "yazi-cwd.XXXXXX")
	^yazi ...$args --cwd-file $tmp
	let cwd = (open $tmp)
	if $cwd != "" and $cwd != $env.PWD {
		cd $cwd
	}
	rm -fp $tmp
}

# def chezmoi-edit-apply[name?: path]: nothing -> any {
#   let editor = if name | is-empty { }  $"(get-editor) "
#   let args = [-c $'nu -c "watch \"(chezmoi source-path)\" {|| chezmoi apply --no-tty}" & apply=$! ; hx . ; kill $apply']
#   run-external sh ...$args
# }
