# Repository Guidelines

## Project Structure & Module Organization

This is a cross-platform chezmoi dotfiles repository. `.chezmoiroot` points to `home/`, so files there map to the user's home directory using chezmoi naming rules: `dot_config/` becomes `~/.config/`, `private_dot_ssh/` receives private permissions, and `executable_*` files are installed as executables. OS-specific lifecycle scripts live in `home/.chezmoiscripts/{linux,darwin,windows}/`. Distrobox manifests are installed from `home/dot_config/distrobox/assemble/`, `root/` describes desired system-level image contents, and `install.sh` bootstraps chezmoi. Files ending in `.tmpl` are Go templates; `.age` files are encrypted secrets.

`root/` is not part of the chezmoi source state, and no automated path currently synchronizes it to the live host or a custom image. When working on a corresponding system file, inspect the live file as the current operational state. Update `root/` only when the requested goal image should change; do not assume either copy is deployed from the other or introduce a chezmoi/custom-image delivery path without an explicit decision.

## Build, Test, and Development Commands

- `chezmoi diff`: preview differences between this source state and the current machine.
- `chezmoi apply --dry-run --verbose`: inspect planned changes and scripts without applying them.
- `chezmoi apply --init --verbose`: apply the source state; this can install packages or run lifecycle scripts, so review the diff first.
- `chezmoi doctor`: check the local chezmoi installation and dependencies.
- `mise run test:e2e:linux`: run the standard chezmoi E2E test on Fedora 44 and the Ubuntu 24.04 desktop/headless devcontainers.
- `mise run test:e2e:linux:bazzite`: run the slow privileged Bazzite E2E test locally.
- `mise run test:e2e`: run the standard Linux E2E on Linux or the local Tart E2E on macOS. Linux hosts do not run macOS E2E remotely.
- `./install.sh`: bootstrap and apply this checkout on a new machine.

There is no compilation step. Validate on the relevant operating system, especially after changing `.chezmoiscripts` or platform-conditional templates.

## Chezmoi Source Workflow

- Inspect rendered changes with `chezmoi diff <target>` before applying them.
- Do not try `chezmoi apply <target>` inside the sandbox first. Request `require_escalated` approval
  for every execution without using an existing persistent approval, requesting a `prefix_rule`, or
  granting permanent write access to the chezmoi state database.
- Apply only explicitly named targets and confirm their diffs are empty afterward. Never run an
  untargeted bulk `chezmoi apply`.
- When a newly managed nested target has missing parent directories, include each required parent
  from top to bottom together with the file as explicit apply targets. Applying only the file fails
  before chezmoi creates its missing parents.

## Immutable Fedora Application Installation

On immutable Fedora systems such as Bazzite, do not treat the availability of a Fedora RPM as making an application a suitable installation candidate. Host package installation does not use `dnf`, and `rpm-ostree` package layering must not be used to install applications. Prefer simple user-space options such as mise-compatible upstream binaries, portable upstream artifacts, Flatpak, or an existing container image.

If no simple option is viable, the final fallback may be to propose adding an Arch-based Distrobox image to [`atty303/distrobox-image`](https://github.com/atty303/distrobox-image). Do not modify that repository or publish an image without a separate explicit request.

## Distrobox Runtime Inspection

Run commands inside a Distrobox container with `distrobox enter <name> -- <command>`. Do not use
`podman exec` to inspect GUI, D-Bus, Wayland, or XDG session state because it bypasses Distrobox's
login and session environment setup. Use read-only `podman` commands only for container-engine
lifecycle, storage, or metadata inspection.

## Coding Style & Naming Conventions

Preserve the format native to each tool (TOML, JSON, KDL, Lua, Nushell, POSIX shell, or PowerShell). Use existing indentation in nearby files and keep shell scripts portable when they declare `#!/bin/sh`. Follow chezmoi attributes exactly: `dot_`, `private_`, `executable_`, `symlink_`, `encrypted_`, and `remove_`. Name lifecycle scripts with chezmoi ordering semantics, for example `run_onchange_after_mise.sh.tmpl`.

## Testing Guidelines

Run `chezmoi diff` and the dry run before committing. Inspect rendered templates for every affected OS and confirm secret material remains encrypted. Use `mise run test` for the host-native full verification: Linux hosts run the standard Linux E2E and macOS hosts run the local Tart E2E; do not require a Linux host to run macOS E2E remotely. Run `mise run test:e2e:linux` after changing files under `home/.chezmoiscripts/linux/` or changing `install.sh`. The Bazzite E2E is exceptionally slow: run `mise run test:e2e:linux:bazzite` only when the change affects Bazzite-specific Flatpak, Distrobox, privileged systemd, or related integration behavior, and obtain explicit user approval immediately before every run. For executable changes, also run the language's parser or formatter when available.

For Nushell menu or keybinding changes, do not treat isolated function calls as final verification. Use an interactive Nushell session with all autoload files loaded, then verify the actual key input, candidate updates while typing, selection result, and resulting command-line buffer.

## Commit & Pull Request Guidelines

History favors short imperative Conventional Commit subjects such as `feat: add fzf configuration` and `fix: update background-opacity`. Use a focused subject and keep unrelated platform changes separate. Pull requests should describe affected OSes, summarize rendered-file impact, list validation commands, and include screenshots only for visible desktop or terminal changes. Never commit plaintext credentials, tokens, host keys, or decrypted `.age` content.

The `origin` remote uses HTTPS and is reserved for fetch and pull. Push this repository through the SSH-only `ssh` remote with `git push ssh <branch>`; do not use `git push origin`.
