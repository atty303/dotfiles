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

Normal mode always uses `--app=<URL>`. It does not depend on policy or Sync completing a local web
app installation. Chrome derives a stable Wayland app ID from each fixed URL, while the dedicated
user data directory keeps each application's browser state separate. Browser mode opens
`chrome://policy` in the same dedicated profile for Google Account sign-in, Sync, extension
maintenance, and diagnostics.

Chezmoi owns the visible desktop entries and hicolor icons. Desktop entries call the absolute
launcher path and do not depend on the graphical session's `PATH`. Scroll matches the resulting
Wayland app IDs:

```text
chrome-x.com__-Default
chrome-www.youtube.com__-Default
```

## X integration

The X integration uses a repository-managed Manifest V3 extension from
`~/.config/chrome-web-apps/x-integration`. It is not installed through policy, Chrome Sync, or the
Chrome Web Store. Google Chrome does not support loading it from a command-line flag, so it must be
loaded once in the X profile. Chrome retains that installation in the profile. The YouTube and
regular Chrome profiles do not use the extension.

The extension recognizes X photo and video URLs and prefixes the window title with `⟦X media⟧`.
Scroll's in-process Lua callback converts that marker into the `x-media` mark. When media opens from
the normal tiled X window, Lua adds `x-media-auto-float` and enables floating. When media closes, it
returns to tiling only if Lua originally enabled floating; a window that was already floating stays
floating.

HTTP(S) links outside `x.com`, `twitter.com`, and their subdomains are encoded into the
`x-open-default:` URL scheme. The user-level desktop handler validates and decodes the URL, then
passes it as one argument to `xdg-open`. This follows the current XDG default browser instead of
hard-coding Zen. Chrome may ask for confirmation the first time the external handler is used.

The Linux lifecycle script registers `open-in-default-browser.desktop` as the handler for
`x-scheme-handler/x-open-default`. It requires `xdg-mime` and `update-desktop-database` on a live
desktop; the bridge itself requires `xdg-open`.

## Initial setup and verification

Run the normal `chezmoi apply`. The Linux lifecycle script registers the custom scheme during the
apply. Confirm afterward that the `[Default Applications]` section in
`${XDG_CONFIG_HOME:-$HOME/.config}/mimeapps.list` contains:

```ini
x-scheme-handler/x-open-default=open-in-default-browser.desktop
```

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

For the X profile, also install the repository-managed integration extension:

1. Run `chrome-web-app x --browser`.
2. Open `chrome://extensions` and enable **Developer mode**.
3. Select **Load unpacked**, then choose `~/.config/chrome-web-apps/x-integration`.
4. Confirm **X PWA integration** is enabled and remains present after fully closing and reopening
   the X profile.
5. Open an X photo or video and confirm the window floats; close the media viewer and confirm a
   previously tiled window returns to tiling.
6. Open an external HTTP(S) link and approve the `x-open-default` handler if Chrome prompts. Confirm
   the link opens in the current XDG default browser.

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
