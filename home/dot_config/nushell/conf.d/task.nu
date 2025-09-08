# Generate a new repository from a template
export def gen-repo [
    --name: string # The name of the repository to create
]: nothing -> path {
  let name = if $name == null {
    (input "Repository name: ")
  } else {
    $name
  }
  let scope_dir = ($env.SRC_ROOT | path join "github.com" "atty303")
  mkdir $scope_dir
  mise exec --raw github:cargo-generate/cargo-generate -- cargo-generate generate --git https://github.com/atty303/repository-template.git --name $name --allow-commands --vcs git --destination $scope_dir
  $scope_dir | path join $name
}
