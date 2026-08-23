# Dotfiles

This repository is the chezmoi source state for atty303's personal development and
desktop environments. It is intended to reproduce those environments across Linux,
macOS, and Windows while keeping shared command-line tools and configuration under one
source of truth.

This is not a general-purpose dotfiles distribution. It contains personal identities,
encrypted secrets, host-specific desktop configuration, and assumptions about external
accounts. Do not apply it unchanged on another person's machine. The repository is
public as a reference for its structure and policy, not as a supported base for forks.

## Direction

The long-term goal is for a clean installation of each maintained operating system to
converge on the intended environment from a single bootstrap command. Platform-specific
behavior should be limited to integration that cannot sensibly be shared, and each
maintained bootstrap path should eventually be exercised in a disposable clean
environment.

The repository follows these principles:

- **chezmoi owns convergence.** Managed files, templates, encrypted data, external
  resources, and lifecycle scripts describe the desired home-directory state.
- **Portable tools are installed in user space.** Cross-platform command-line tools are
  exposed through versioned mise tool stubs in `~/.local/bin`. The stubs pin release
  artifacts and checksums where the upstream provides them.
- **Native integration stays native.** OS settings and applications use the narrowest
  suitable platform mechanism: mise package bootstrap on macOS, winget and DSC on
  Windows, and user services or Distrobox where Linux desktop integration requires
  them.
- **Immutable Linux hosts remain immutable.** Applications are not installed by layering
  RPMs onto systems such as Bazzite. Portable upstream artifacts, Flatpak, and existing
  container images are preferred; Distrobox is used when an application needs a mutable
  userspace.
- **Shared configuration is the baseline.** Optional differences are selected through
  the `development`, `desktop`, `gaming`, `secrets`, and `work` roles; OS and WSL remain
  separate environment facts.
- **Bootstrap secrets are encrypted at rest.** Optional copies used to shorten initial
  setup are committed only in age-encrypted form. They do not replace the external
  systems that own the underlying credentials. The age identity is provisioned
  separately and stored with private permissions.
- **Applying twice should be safe.** Change-triggered scripts derive their inputs from
  the managed source, and important desktop-container updates preserve enough state to
  recover from a failed transition.
- **External account state stays external.** Account login, cloud synchronization,
  password-manager setup, input methods, and hardware-specific setup remain manual when
  they cannot be made reproducible without coupling the repository to an external
  service or device.

The rationale behind the current tool and platform choices is recorded in
[`docs/technology-selection.md`](docs/technology-selection.md).

## Responsibility boundaries

| Layer | Responsibility |
| --- | --- |
| chezmoi | Render and apply files, select machine-specific state, decrypt secrets, and run lifecycle scripts |
| mise | Bootstrap runtimes, portable CLI tools, and supported package backends |
| OS-native tooling | Configure system settings and applications that require native integration |
| Distrobox and user services | Run and coordinate selected Linux desktop components without modifying the immutable host |
| Manual setup | Authenticate external accounts and configure state that is personal, remote, or hardware-bound |

The source root is [`home/`](home/), as declared by [`.chezmoiroot`](.chezmoiroot).
Chezmoi naming conventions map that tree into the home directory. System-level files
that cannot live there are kept separately under [`root/`](root/).

## Current status

The direction above is stricter than the current implementation. The present validation
level is:

| Environment | Current automation and validation |
| --- | --- |
| Fedora 44 compatibility | Full bootstrap and repeat-apply E2E in a clean Podman container |
| Ubuntu 24.04 desktop devcontainer | Full bootstrap and repeat-apply E2E with desktop command capabilities |
| Ubuntu 24.04 headless devcontainer | Full bootstrap and repeat-apply E2E without desktop command capabilities |
| Bazzite 44 desktop | Local-only privileged integration E2E for Flatpak, Distrobox, and systemd behavior |
| Apple Silicon macOS | Local Tart E2E for bootstrap, encrypted files, packages, symlinks, and idempotence |

Windows has package and configuration automation, but its clean-environment E2E remains a
future design rather than part of the current validation guarantee.

Roles are fixed during `chezmoi init` and stored in the chezmoi config. A normal apply
does not inspect the current session or infer roles again.

## Owner bootstrap

The default `secrets` role requires access to the repository's age identity or the
passphrase used to decrypt the committed identity. The first apply stores that identity
at `~/.config/chezmoi/age/identity.txt`, so later applies do not require it again.
These commands are for the repository owner.

On Linux or macOS, use a checkout of this repository:

```sh
./install.sh
```

The default is fully non-interactive. `development` and `secrets` are always selected;
macOS also selects `desktop`, while Linux selects it only when a `.desktop` session
definition exists under `/usr/share/wayland-sessions` or `/usr/share/xsessions`.
Select a different combination interactively with:

```sh
./install.sh --prompt-roles
```

On Windows 11 24H2 or later:

1. Grant the account the **Create symbolic links** user right in `gpedit.msc`, then sign
   out or reboot.
2. Open Windows Terminal as Administrator and run:

```powershell
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo" `
  -Name "Enabled" -Value 3 -PropertyType DWord -Force
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
./install.ps1
```

Use `./install.ps1 --prompt-roles` to replace the Windows defaults (`development`,
`desktop`, and `secrets`). Enter `-` at the role prompt for a valid baseline-only configuration. Both
wrappers pass any other arguments through to `chezmoi init`. `work` is reserved for
future policy exclusions on managed work devices; it currently adds no settings. Account-backed
applications such as Atuin and 1Password still require their normal login and sync.
Disable `secrets` when their encrypted bootstrap artifacts should not be managed.

After this roles redesign, existing installations must run the wrapper once again (with
`--prompt-roles` when the defaults are not appropriate) to regenerate the chezmoi config.

## Home backups

The Linux host `cristina` has a host-scoped restic configuration for daily encrypted
home-directory backups. It is rendered only when the `secrets` role is selected and the
current hostname has an enabled entry in `home/.chezmoidata/restic.toml`. Other hosts and
operating systems do not manage the wrapper, credentials, or timers until they receive an
explicit host entry and native scheduler integration.

Create a private Backblaze B2 bucket without Object Lock, configure its lifecycle to keep
only the latest version of each object, and create a standard Read and Write application
key restricted to both that bucket and the `restic/cristina/` prefix. Do not use the
account master key. Put these exact unquoted assignments in
`~/.config/restic/credentials/cristina.env`:

```text
AWS_ACCESS_KEY_ID=REPLACE_WITH_KEY_ID
AWS_SECRET_ACCESS_KEY=REPLACE_WITH_APPLICATION_KEY
RESTIC_REPOSITORY=s3:https://REPLACE_WITH_ENDPOINT/REPLACE_WITH_BUCKET/restic/cristina
```

Put a generated restic repository password on one line in
`~/.config/restic/passwords/cristina`, then restrict and encrypt both files into the
chezmoi source state:

```nu
^chmod 700 ~/.config/restic ~/.config/restic/credentials ~/.config/restic/passwords
```

```nu
^chmod 600 ~/.config/restic/credentials/cristina.env ~/.config/restic/passwords/cristina
```

```nu
chezmoi add --encrypt ~/.config/restic/credentials/cristina.env
```

```nu
chezmoi add --encrypt ~/.config/restic/passwords/cristina
```

Apply the credentials, wrapper, exclude file, services, and timer unit files as explicit
targets. Timer enablement is intentionally not part of the chezmoi source state, so a fresh
bootstrap cannot schedule maintenance before its repository has been verified. Initialize
the repository, create the first snapshot, run a check, and restore a representative file
to a temporary directory before enabling automatic execution:

```nu
restic-home init
```

```nu
restic-home backup
```

```nu
restic-home check
```

After the restore comparison succeeds, explicitly enable and start the timers:

```nu
systemctl --user daemon-reload
```

```nu
systemctl --user enable --now restic-backup.timer restic-maintenance.timer restic-check.timer
```

Backup, retention, and integrity failures remain visible as failed user units in the
journal and also trigger a desktop notification. If the host entry is disabled, the host
becomes unknown, or the `secrets` role is removed, the next full chezmoi apply stops the
timers and removes the host-scoped credentials and automation files.

## Maintenance

Preview source-state changes before applying them:

```sh
chezmoi diff
chezmoi apply --dry-run --verbose
```

During focused edits, apply only the target being changed and verify that its diff is
then empty:

```sh
chezmoi apply ~/.config/example/config.toml
chezmoi diff ~/.config/example/config.toml
```

### System configuration

The `root/` source state holds a small set of Linux system files and is separate from the
normal HOME source state. System commands require one or more normalized absolute file
targets that already exist in `root/`; they reject directories and never apply all of `/`.

Preview, apply, and verify an explicitly selected file:

```sh
mise run system:diff -- /etc/udev/rules.d/70-atty-usb-serial.rules
mise run system:apply -- /etc/udev/rules.d/70-atty-usb-serial.rules
mise run system:verify -- /etc/udev/rules.d/70-atty-usb-serial.rules
```

Only `system:apply` uses `sudo`. It installs the declaration but does not activate the
subsystem-specific setting. The USB serial rule grants the active local seat access to
`ttyACM*` and `ttyUSB*` devices through udev's `uaccess` ACL support. Reload udev after
applying:

```sh
sudo udevadm control --reload
```

Reconnect the USB serial device, then confirm that its ACL grants read/write access to
the active desktop user's UID. Processes with that UID, including SSH processes or
background services, can use the ACL while the local seat remains active. The rule does
not guarantee persistent access for an SSH-only login or a service when no local seat is
active.

Repository checks are exposed through mise. The main suites are:

```sh
mise run check
mise run fix
mise run test
mise run test:e2e
mise run test:e2e:harness
mise run test:e2e:linux:bazzite
mise run test:e2e:mac:prepare
mise run test:e2e:mac:local
```

`check` and `fix` accept optional file paths and otherwise operate on the whole
repository. Installing the mise tools also installs the repository's hk pre-commit
hook. The complete `test` task selects its full E2E from the host OS: Linux runs the
Fedora and Ubuntu suites, while macOS runs the local Tart suite. Linux does not reach a
remote Mac. The Bazzite task is a slow, local-only integration check and is not included
in the standard Linux or CI path. The macOS tasks require an Apple Silicon Mac with Tart.
See the
[chezmoi template reference](https://www.chezmoi.io/reference/templates/) when editing
Go templates in the source state.
