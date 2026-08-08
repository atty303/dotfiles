# Repository Guidelines

## Project Structure & Module Organization

This is a cross-platform chezmoi dotfiles repository. `.chezmoiroot` points to `home/`, so files there map to the user's home directory using chezmoi naming rules: `dot_config/` becomes `~/.config/`, `private_dot_ssh/` receives private permissions, and `executable_*` files are installed as executables. OS-specific lifecycle scripts live in `home/.chezmoiscripts/{linux,darwin,windows}/`. Top-level `distrobox/` contains container definitions, `root/` contains system-level files, and `install.sh` bootstraps chezmoi. Files ending in `.tmpl` are Go templates; `.age` files are encrypted secrets.

## Build, Test, and Development Commands

- `chezmoi diff`: preview differences between this source state and the current machine.
- `chezmoi apply --dry-run --verbose`: inspect planned changes and scripts without applying them.
- `chezmoi apply --init --verbose`: apply the source state; this can install packages or run lifecycle scripts, so review the diff first.
- `chezmoi doctor`: check the local chezmoi installation and dependencies.
- `mise run test:e2e:linux`: run the full chezmoi E2E test on Fedora 44 and Ubuntu 24.04.
- `./install.sh`: bootstrap and apply this checkout on a new machine.

There is no compilation step. Validate on the relevant operating system, especially after changing `.chezmoiscripts` or platform-conditional templates.

## Immutable Fedora Application Installation

On immutable Fedora systems such as Bazzite, do not treat the availability of a Fedora RPM as making an application a suitable installation candidate. Host package installation does not use `dnf`, and `rpm-ostree` package layering must not be used to install applications. Prefer simple user-space options such as mise-compatible upstream binaries, portable upstream artifacts, Flatpak, or an existing container image.

If no simple option is viable, the final fallback may be to propose adding an Arch-based Distrobox image to [`atty303/distrobox-image`](https://github.com/atty303/distrobox-image). Do not modify that repository or publish an image without a separate explicit request.

## Coding Style & Naming Conventions

Preserve the format native to each tool (TOML, JSON, KDL, Lua, Nushell, POSIX shell, or PowerShell). Use existing indentation in nearby files and keep shell scripts portable when they declare `#!/bin/sh`. Follow chezmoi attributes exactly: `dot_`, `private_`, `executable_`, `symlink_`, `encrypted_`, and `remove_`. Name lifecycle scripts with chezmoi ordering semantics, for example `run_onchange_after_mise.sh.tmpl`.

## Testing Guidelines

Run `chezmoi diff` and the dry run before committing. Inspect rendered templates for every affected OS and confirm secret material remains encrypted. Run `mise run test:e2e:linux` after changing files under `home/.chezmoiscripts/linux/` or changing `install.sh`. For executable changes, also run the language's parser or formatter when available.

## Commit & Pull Request Guidelines

History favors short imperative Conventional Commit subjects such as `feat: add fzf configuration` and `fix: update background-opacity`. Use a focused subject and keep unrelated platform changes separate. Pull requests should describe affected OSes, summarize rendered-file impact, list validation commands, and include screenshots only for visible desktop or terminal changes. Never commit plaintext credentials, tokens, host keys, or decrypted `.age` content.
