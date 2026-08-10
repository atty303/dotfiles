# Linux Chrome PWA declarative configuration

## Goal

Manage X and YouTube as independent Chrome Flatpak applications on Linux. Each application uses a
dedicated Chrome user data directory, so cookies, site logins, histories, and local settings do not
leak between the applications or Zen. The same Google Account and Chrome Sync provide the shared
extension set; extension independence is intentionally not provided.

## Application definitions

`home/.chezmoidata/linux.toml` is the single source of truth for application keys, names, URLs,
Chrome web app IDs, and notification origins.

| Key | Name | URL | Web app ID |
| --- | --- | --- | --- |
| `x` | X | `https://x.com/` | `lodlkdfmihgonocnmddehnfgiljnadcf` |
| `youtube` | YouTube | `https://www.youtube.com/` | `agimnkijcaahngcdmfeangaknmldooml` |

Chezmoi renders `~/.config/chrome-web-apps/web-apps.json` with only:

- `WebAppInstallForceList`, which installs both applications as windows without Chrome-generated
  desktop shortcuts;
- `BackgroundModeEnabled: false`, which stops a dedicated Chrome process after its last window
  closes.

Extensions, notifications, browser sign-in, and Sync are not controlled by policy. Chrome Sync is
the source of truth for extensions. Site notification permissions and extension-specific options
are configured manually.

## Portable Flatpak policy injection

Google Chrome reads Linux policies from `/etc/opt/chrome/policies`, but the host filesystem is not
modified. `chrome-web-app` exposes the user-owned policy directory read-only to the Flatpak sandbox,
copies the policy to the sandbox's temporary managed-policy directory with mode `0444`, and then
starts Chrome. The sandbox-local copy disappears with the Flatpak instance.

This design does not use host `/etc`, `sudo`, a persistent Flatpak override, a lifecycle script, or
package modification. The policy applies only to Chrome processes started by `chrome-web-app`; a
normally launched Chrome `Default` profile does not receive it directly. Chrome Sync may still make
the applications and extensions visible in `Default`, which is accepted.

## Launcher and desktop integration

The launcher interface is:

```text
chrome-web-app x
chrome-web-app youtube
chrome-web-app x --browser
chrome-web-app youtube --browser
```

It supports only the system installation of `com.google.Chrome`. Dedicated user data directories
are stored at:

```text
$HOME/.var/app/com.google.Chrome/config/google-chrome-web-apps/<key>
```

Normal mode uses `--app=<URL>` until the target application's exact manifest resource directory
exists, then switches to `--app-id=<ID>`. Browser mode opens `chrome://policy` in the same dedicated
profile for Google Account sign-in, Sync, extension maintenance, and diagnostics.

Chezmoi owns the visible desktop entries and hicolor icons. Desktop entries call the absolute
launcher path and do not depend on the graphical session's `PATH`. Scroll matches the resulting
Wayland app IDs:

```text
chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default
chrome-agimnkijcaahngcdmfeangaknmldooml-Default
```

## Initial setup and verification

Apply only the policy, launcher, desktop entries, icons, Scroll configuration, and any required
parent directories. Do not run an untargeted `chezmoi apply`.

For both dedicated profiles:

1. Open browser mode, confirm the two policies are valid in `chrome://policy`, and sign in to the
   same Google Account used by `Default`.
2. Enable Sync for Extensions. Disable history, tabs, bookmarks, passwords, or other categories
   that should remain local.
3. Wait for extensions to appear and approve any requested permissions.
4. Allow the target site's notification permission and configure extension options that do not
   sync.
5. Launch the desktop entry and confirm the target app ID exists under `Manifest Resources`, the
   window is placed in the intended Scroll workspace, and closing the last window terminates that
   dedicated Chrome process.
6. Confirm local cookies, site login sessions, and history do not appear in the other dedicated
   profile or Zen.

If the same Google Account cannot enable Sync in both dedicated user data directories, stop the
cutover and retain the old profiles.

## Fresh cutover

Do not copy profile state or add compatibility launchers. After both applications pass verification
and manual setup is complete, resolve and display every deletion target and obtain explicit
confirmation before removing only:

- `$HOME/.var/app/com.google.Chrome/config/google-chrome/X`;
- `$HOME/.var/app/com.google.Chrome/config/google-chrome/youtube`;
- their Chrome-generated desktop entries;
- icons generated specifically for those old shortcuts.

Never copy, move, or delete the existing `Default` profile.
