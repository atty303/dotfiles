---
name: upgrade-tool-versions
description: dotfilesで管理するmise tool stubとimmutable Distrobox imageの最新版、変更価値、破壊的変更を調査し、選択された更新と必要な移行を反映するときに使用する。
---

# Tool Version Upgrades

## Establish the target

- Read every applicable `AGENTS.md` and repository instruction before inspecting or changing files.
- For home-directory targets, run `chezmoi source-path` with a path under `~` or `/home`; edit the returned source state, never the target file.
- Accept zero or more tool or Distrobox names. With no names, inventory every supported source. With names, limit network research and changes to those names.
- Support these sources:
  - Executable files whose first line is `#!/usr/bin/env -S mise tool-stub`.
  - Distrobox manifests pinned to immutable images published by `atty303/distrobox-image`.
- Report symbolic versions and floating image references as reproducibility risks, but do not rewrite them automatically.

## Inventory versions

### Mise tool stubs

- Read `tool` and `version` from each source stub. Treat the stub filename as the command name; do not assume it matches the mise tool identifier.
- Run `mise latest <tool>` to find the latest stable release. Do not constrain the major version.
- When the current version is a prerelease, also identify the newest release in the same prerelease channel, but keep the latest stable release as the primary candidate.
- Treat an exact version whose embedded lock URLs reference another version as an inconsistent stub that needs regeneration even when no newer version exists. Report declared, locked, and installed versions separately; research changes from the oldest artifact that a fresh installation could resolve through the candidate version.

### Distrobox images

- Read every assemble manifest, but only offer automatic updates for exact immutable tags or digests from `ghcr.io/atty303/*` that correspond to `atty303/distrobox-image`.
- Find the newest published immutable reference across successful `Build immutable images` workflow runs. Prefer a non-empty `production-results` artifact because `publish-result.json` contains the exact tag and digest. When the newest successful run published nothing, walk backward to the run that published the newest extant tag and corroborate it with the resolved plan, run summary, or registry metadata.
- Determine the contained application version from an image label or production lock, then an immutable tag, a live container version command, or a manifest comment, in that order. State the evidence used and lower confidence when only a comment is available. If the current or candidate application version cannot be established, stop before recommending or changing that image.
- Find the latest upstream application release independently of the latest available immutable image. Report when upstream is newer and do not describe the image candidate as the latest application release.
- Preserve whether the manifest uses an immutable tag or digest. Keep an adjacent application-version comment synchronized when present.

## Research the upgrade

- Use first-party release notes, CHANGELOGs, migration guides, security advisories, and documentation. For GitHub projects, prefer Releases and repository CHANGELOGs; use a tag/commit comparison only to fill gaps.
- Cover every release after the current version through the candidate version, not just the newest release page.
- Search the dotfiles repository for configuration, command-line flags, plugins, shell integrations, services, and scripts affected by announced changes.
- Present one candidate at a time with:
  - Current and candidate versions or image references.
  - Whether the action is a version change, lock regeneration, or image-reference change.
  - Release dates and links to the first-party evidence.
  - High-value features, fixes, performance improvements, and security changes relevant to this repository.
  - Breaking changes, deprecations, migrations, and platform support changes.
  - Concrete local files or behaviors affected.
  - A recommendation of `upgrade`, `defer`, or `no change`, with confidence and rationale.
- Do not equate breaking changes with a reason to defer. Recommend upgrading when the value is material and the required migration is understood and testable.
- Mark claims as uncertain when first-party evidence is incomplete. If compatibility or migration cannot be assessed, recommend deferring and make no changes.
- Wait for an explicit update choice for that candidate before moving to the next one. A request to investigate is not approval to update.

## Apply an approved update

### Mise tool stubs

- Regenerate the source stub atomically with:

  ```sh
  mise generate tool-stub <source-path> --lock --version <exact-version>
  ```

- Do not hand-edit generated lock URLs or checksums. Confirm the declared version, every embedded versioned URL, and the resolved lock agree.
- Apply every required configuration or invocation migration in the same logical change. Do not retain compatibility aliases or old branches unless the current requirements need them.

### Distrobox images

- Replace only the selected manifest's immutable reference and synchronized version comment.
- Use the repository's existing lifecycle path for container replacement, service restart, state recording, and rollback. Do not duplicate it with an ad hoc `distrobox assemble --replace` command when chezmoi already owns that lifecycle.
- Explain interruption and rollback behavior immediately before live replacement. For Scroll, preserve its transactional next-session workflow and report a prepared candidate as pending rather than active.

## Verify and finish

- Run the cheapest relevant static and repository checks first, then runtime checks proportional to the affected tool or image.
- Run `chezmoi diff <target>` before applying. For each exact target, request approval and run `chezmoi apply <target>` with elevated sandbox permission; never request a permanent approval or apply without a target.
- After applying a tool stub, determine a version flag that does not intentionally initialize or migrate user state, run it from a temporary working directory outside the source repository with temporary `HOME` and XDG directories, and confirm it reports the selected version. A repository-local `mise.toml` can otherwise require trust in the temporary profile and fail before the tool executes; do not mutate trust state merely to make the check pass. If the tool has no isolatable version check, report that runtime verification as unavailable instead of executing it against the real profile.
- After applying a Distrobox update, inspect the container image reference, lifecycle state files, and associated user service. Treat pending, rollback, failed, or inactive states distinctly.
- Confirm `chezmoi diff <target>` is empty after application. On failure, preserve the previous working target/container, report the observed state and recovery path, and do not continue to the next candidate.
- A fresh independent review is not required when the complete source change is limited to one mise tool stub regenerated with the required `mise generate tool-stub ... --lock --version <exact-version>` command. Still inspect the exact diff and complete every static, lock-consistency, chezmoi, and isolated runtime verification required by this skill.
- Follow the repository's independent-review requirements when the change also includes a configuration or invocation migration, another source file, a hand-edited generated field, or a Distrobox image update. Follow its version-control requirements for every change, commit each completed logical update locally when required, and never push without an explicit request.

## Stop conditions

- Stop before mutation when the latest version, exact immutable image, first-party change evidence, migration, or affected source target cannot be determined reliably.
- Stop before live application when the required approval is denied or the existing rollback path is unavailable.
- Never update floating images, publish container images, modify `atty303/distrobox-image`, add dependencies, or broaden to other version sources without a separate explicit decision.
