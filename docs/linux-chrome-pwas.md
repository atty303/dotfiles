# Linux Chrome PWA declarative configuration plan

Status: planned, not implemented

## Goal

Manage Chrome PWAs on Linux from the chezmoi source state. X and YouTube run as independent applications with separate Chrome user data directories, cookies, Google logins, histories, and extension settings. The normal browser is Zen and remains unaffected.

Prefer standard host integration and maintainability over additional Flatpak sandbox isolation. The initial implementation covers X and YouTube; another PWA can be added through the same application definition, policy, and desktop-entry structure.

## Design

Use the system Flatpak installation of Google Chrome, `com.google.Chrome`, through its standard launcher. Chrome supports force-installing PWAs with [`WebAppInstallForceList`](https://chromeenterprise.google/policies/web-app-install-force-list/), applying policies at profile level, and selecting independent storage with [`--user-data-dir`](https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/user_data_dir.md).

Install one host policy at `/etc/opt/chrome/policies/managed/web-apps.json`. The Flatpak package already exposes host `/etc` and imports this standard Chrome policy path, so no custom sandbox, private policy injection, package-internal entry point, or Flatpak override is required.

Chrome host policies apply to every Chrome profile. Therefore, both dedicated PWA profiles and the existing Chrome `Default` profile receive the two PWA definitions, the union of the six extensions, and both notification origins. This policy-driven change to `Default` is an accepted simplicity tradeoff: the profiles still do not share runtime data, Chrome is not the normal browser, and Zen does not read Chrome policies. Do not add per-profile policy emulation or compatibility layers.

Store the application definitions in `home/.chezmoidata/linux.toml` as the single source of truth. Each definition contains:

- key and display name;
- start URL and known Chrome web app ID;
- notification origin;
- Chrome Web Store extension IDs associated with the application.

Initial definitions:

| Key | Name | URL | Web app ID |
| --- | --- | --- | --- |
| `x` | X | `https://x.com/` | `lodlkdfmihgonocnmddehnfgiljnadcf` |
| `youtube` | YouTube | `https://www.youtube.com/` | `agimnkijcaahngcdmfeangaknmldooml` |

Generate the host policy with:

- `WebAppInstallForceList` containing X and YouTube, launched in windows, with `create_desktop_shortcut` set to `false`;
- [`ExtensionSettings`](https://chromeenterprise.google/policies/extension-settings/) entries using `normal_installed` and the Chrome Web Store update URL, so extensions are installed automatically but may be disabled by the user;
- `NotificationsAllowedForUrls` containing `https://x.com` and `https://www.youtube.com`;
- `BackgroundModeEnabled` set to `false`;
- no policy for language, camera, microphone, downloads, or other site permissions.

Declare these extensions:

| Application | Extension | ID |
| --- | --- | --- |
| X | Xetter | `bigjedfebadeogmcnfaepncnhkjnneik` |
| X | TwitterTimelineLoader | `ipmgjpmedafkmmadinmeoannpofakpbh` |
| X | Control Panel for Twitter | `kpmjjdhbcfebfjgdnpjagcndoelnidfj` |
| X | X Auto Refresher | `mihjenkihajdgclhgheccildhbocbheb` |
| YouTube | YouTube LiveChat Flusher | `kkjglcpgfpjlaloboikfcoofameeljbe` |
| YouTube | Enhancer for YouTube | `ponfpcnoihfmfllpaingbgckeeldkhle` |

Render the policy first to a user-readable target under `~/.config/chrome-web-apps/web-apps.json`. A Linux `run_onchange_after_...` script keyed by the rendered policy hash runs after target generation and installs that exact file to the host policy path with `sudo install -Dm0644`; this ordering applies on both initial creation and updates. The script must show the source and destination paths, request elevation normally, and never modify another Chrome policy file. Removing this feature requires a separate explicit uninstall operation; an empty policy must not silently replace the host file.

## Launcher and desktop integration

Add an executable with this interface:

```text
chrome-web-app x
chrome-web-app youtube
chrome-web-app x --browser
chrome-web-app youtube --browser
```

The launcher must:

1. accept only `x` or `youtube` and reject extra or unknown arguments;
2. use `flatpak --system` for availability checks and launch, without falling back to a user installation;
3. fail clearly when the system installation of `com.google.Chrome` is unavailable;
4. construct the dedicated user data directory on the host as the absolute path `$HOME/.var/app/com.google.Chrome/config/google-chrome-web-apps/<key>` and pass it directly as `--user-data-dir`; do not expand host `$XDG_CONFIG_HOME` or defer path expansion to the Flatpak environment;
5. add `--no-first-run` and `--no-default-browser-check`;
6. in default mode, open `--app=<URL>` until `<user-data-dir>/Default/Web Applications/Manifest Resources/<target-app-id>` exists, then use `--app-id=<target-app-id>`; another policy-installed PWA's manifest must not satisfy readiness;
7. in `--browser` mode, use the same user data directory but open a normal browser window for `chrome://policy`, `chrome://extensions`, Google login, and extension option maintenance.

Manage the visible X and YouTube desktop entries and their application icons with chezmoi. Commit suitable icons obtained from the existing PWA manifest resources, install them under the user hicolor icon theme as `chrome-web-app-x` and `chrome-web-app-youtube`, and reference those names from the entries. Render each `Exec` field with the absolute `{{ .chezmoi.homeDir }}/.local/bin/chrome-web-app` path followed by its key; do not depend on the GUI session's `PATH`.

Do not depend on Chrome-generated desktop entries or icons. The host policy disables shortcut creation, and the chezmoi entries are the only user-facing launchers.

Update the Scroll rules for the fresh profiles:

```text
chrome-lodlkdfmihgonocnmddehnfgiljnadcf-Default
chrome-agimnkijcaahngcdmfeangaknmldooml-Default
```

## Fresh cutover

Do not implement state copying, profile aliases, legacy launch paths, or migration code. The new profiles start empty, and Google login and extension-specific options are configured manually.

After both new applications pass verification and the user confirms that login and extension setup are complete, remove only:

- the old `$HOME/.var/app/com.google.Chrome/config/google-chrome/X` and `$HOME/.var/app/com.google.Chrome/config/google-chrome/youtube` profile directories;
- their generated desktop entries;
- icons generated specifically for those old profile shortcuts.

Do not copy, move, or delete the existing `$HOME/.var/app/com.google.Chrome/config/google-chrome/Default` profile. The global policy will still install the declared PWAs and extensions and apply the notification policy when that profile next runs. Resolve and display every exact deletion target before removal.

## Verification

Before applying:

1. render the Linux templates, parse the generated policy as JSON, and confirm the expected PWA URLs, extension IDs, notification origins, and `create_desktop_shortcut: false`;
2. run `bash -n` on the launcher and `run_onchange` script;
3. test rejection of unknown launcher arguments and the missing-system-Flatpak path;
4. inspect `chezmoi diff` and `chezmoi apply --dry-run --verbose` for the explicit affected targets;
5. inspect the exact `sudo install` source, destination, mode, and content before approving elevation.

Apply only the new policy target, policy installer, launcher, desktop entries, icons, and Scroll configuration. Do not run an untargeted `chezmoi apply`. Confirm that a second `chezmoi diff` for those targets is empty and that the installed host policy is byte-for-byte equal to the rendered target.

For each PWA, observe that:

- both policy-declared PWA manifests and all six declared extensions appear in its dedicated user data directory, including the target application's exact web app ID under `Default/Web Applications/Manifest Resources`;
- `chrome://policy` reports the web app, extension, notification, and background policies as valid;
- `--browser` opens the same dedicated profile and permits access to `chrome://policy`, `chrome://extensions`, and extension option pages;
- the desktop entry opens an independent application window and Scroll places it in the configured workspace;
- cookies, login, history, and extension settings do not appear in the other PWA or Zen;
- closing the last window terminates that dedicated Chrome process.

Google login and extension option configuration are the only manual application setup steps. Perform old-profile deletion only after this verification and explicit confirmation.

Because the change adds a Linux lifecycle script, run `mise run test:e2e:linux` after the targeted local verification.

## Constraints and assumptions

- Zen remains the normal browser; the Chrome host policy intentionally applies to every Chrome profile on the machine.
- The system Flatpak installation of `com.google.Chrome` is the only supported Chrome distribution; a user Flatpak installation is never selected.
- `sudo` is required only to install the single host policy file. No package installation or new dependency is introduced.
- Existing PWA profile data is not migrated or preserved after confirmed cutover.
- No remote operation is part of implementation.
