let atuin = $env.USERPROFILE | path join .local bin atuin.exe

if not ($atuin | path exists) {
  http get --raw https://github.com/Magniquick/atuin-win/actions/runs/12970332928/artifacts/2486052128 | save $atuin
}
