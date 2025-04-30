# TODO: Don't push intermidate directories to the stack
export def --wrapped --env main [...args: string] {
  if ($args | take 2) == ["repo", "clone"] and $args.2? != null {
    let repo = $args.2 | split row '/'
    let clone_dir = $env.SRC_ROOT | path join "github.com" $repo.0 | path expand
    print $"Cloning ($repo.0)/($repo.1) to ($clone_dir)"
    mkdir $clone_dir
    cd $clone_dir
    ^gh ...$args
    cd ($clone_dir | path join $repo.1)
  } else if ($args | take 2) == ["codespace", "ssh"] and "--save" in $args {
    let raw_args = [...($args | filter { $in != "--save" }), "--config"]
    let output = (^gh ...$raw_args | complete)

    print ($output.stdout | lines | filter { $in =~ "^Host" })
    $output.stdout | save --force $"~/.ssh/codespaces/current"
  } else {
    ^gh ...$args
  }
}
