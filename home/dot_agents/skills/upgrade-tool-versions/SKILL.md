---
name: upgrade-tool-versions
description: dotfilesで管理するグローバルmise tool定義とlock、およびimmutable Distrobox imageの最新版、変更価値、破壊的変更を調査し、選択された更新と必要な移行を反映するときに使用する。
---

# Tool Version Upgrades

## Establish the target

- Read every applicable `AGENTS.md` and repository instruction before inspecting or changing files.
- For home-directory targets, run `chezmoi source-path` with a path under `~` or `/home`; edit the returned source state, never the target file.
- Accept zero or more tool or Distrobox names. With no names, inventory every supported source. With names, limit network research and changes to those names.
- Support these sources:
  - Tools declared in the chezmoi-managed global mise configuration, including OS-specific configuration files, with their adjacent `mise.lock`.
  - Distrobox manifests pinned to immutable images published by `atty303/distrobox-image`.
- Report symbolic versions and floating image references as reproducibility risks, but do not rewrite them automatically.

## Check version differences before research

- The parent agent performs a lightweight version comparison for every in-scope source before dispatching research. Use `mise latest <tool>` for tool versions and published image metadata for immutable references. Record the current and newest available versions or references, plus any obvious lock inconsistency. Do not perform release-by-release research or edit sources in this pass.
- An exact mise declaration with a missing or inconsistent lock remains a candidate for regeneration even without a version bump. Report declared, locked, and installed versions separately when investigating it. Locate declarations and locks through chezmoi source mapping; repository-local development tools are outside this inventory.
- For Distrobox, compare available published immutable references with the current manifest and check the latest upstream application release separately. If upstream is newer but no newer immutable image is available, report that briefly; do not start a subagent solely for that gap.
- Dispatch each candidate with an available version, lock, or immutable-reference change to its own read-only subagent. Run these investigations concurrently up to the available agent slots; queue the remainder. Give each subagent the source, current and candidate versions or references, and the research requirements below. The parent owns user decisions and all mutations.

## Investigate each candidate

Each candidate subagent completes the applicable checks below before returning a decision-ready report. If subagent execution is unavailable, stop and report which candidates remain uninvestigated; do not silently switch to a lighter investigation.

### Global mise tools

- Read each tool identifier and version request from the global configuration. Resolve command names from registry metadata, `lazy_bins`, and installed executables; do not assume a command name matches the tool identifier. Retain OS and architecture conditions when comparing entries across configuration files.
- Verify the latest stable release with `mise latest <tool>`. Require a non-empty concrete version; exit status alone does not establish successful discovery. Do not constrain the major version.
- When the current version is a prerelease, also identify the newest release in the same prerelease channel, but keep the latest stable release as the primary candidate.
- For HTTP tools, inspect their version-discovery options and first-party distribution source. If `mise latest` cannot discover versions, establish the newest release from that source or mark the candidate unavailable. Treat symbolic channels separately from exact release versions.
- For an inconsistent exact declaration, research changes from the oldest artifact that a fresh installation could resolve through the candidate version.

### Distrobox images

- Read every assemble manifest, but only offer automatic updates for exact immutable tags or digests from `ghcr.io/atty303/*` that correspond to `atty303/distrobox-image`.
- Verify the newest published immutable reference across successful `Build immutable images` workflow runs. Prefer a non-empty `production-results` artifact because `publish-result.json` contains the exact tag and digest. When the newest successful run published nothing, walk backward to the run that published the newest extant tag and corroborate it with the resolved plan, run summary, or registry metadata.
- Determine the contained application version from an image label or production lock, then an immutable tag, a live container version command, or a manifest comment, in that order. State the evidence used and lower confidence when only a comment is available. If the current or candidate application version cannot be established, stop before recommending or changing that image.
- Verify the latest upstream application release independently of the latest available immutable image. Report when upstream is newer and do not describe the image candidate as the latest application release.
- Preserve whether the manifest uses an immutable tag or digest. Keep an adjacent application-version comment synchronized when present.

### Research and report

- Use first-party release notes, CHANGELOGs, migration guides, security advisories, and documentation. For GitHub projects, prefer Releases and repository CHANGELOGs; use a tag/commit comparison only to fill gaps.
- Cover every release after the current version through the candidate version, not just the newest release page.
- Search the dotfiles repository for configuration, command-line flags, plugins, shell integrations, services, and scripts affected by announced changes.
- Return a report to the parent for each candidate with:
  - Current and candidate versions or image references.
  - Whether the action is a version change, lock regeneration, or image-reference change.
  - Release dates and links to the first-party evidence.
  - Highlights of important new features, fixes, performance improvements, and security changes across the researched releases, including material upstream changes without a direct local impact.
  - Breaking changes, deprecations, migrations, and platform support changes.
  - Concrete local files or behaviors affected.
  - A recommendation of `upgrade`, `defer`, or `no change`, with confidence and rationale.
- Do not equate breaking changes with a reason to defer. Recommend upgrading when the value is material and the required migration is understood and testable.
- Mark claims as uncertain when first-party evidence is incomplete. If compatibility or migration cannot be assessed, recommend deferring and make no changes.
- If evidence is insufficient to assess compatibility or migration, mark the candidate unavailable for update and explain the gap. Offer `B` or `C` only; do not offer `A` until the gap is resolved.

## Confirm selections one at a time

- Ask every user-facing question in this workflow in an ordinary assistant reply, not through `AskQuestion`, `AskUserQuestion`, or another question tool. This includes candidate choices, follow-up questions after `C`, and post-commit questions about excluded candidates.
- As subagent reports arrive, the parent presents one decision-ready candidate at a time and waits for its answer. Queue other completed reports while awaiting a response; do not wait for every investigation to finish before asking the first question.
- Use this template as ordinary Markdown, without a code fence, for each candidate choice and for the same candidate's question after `C`. Replace `[tool]` with the command or Distrobox name. In `[調査結果]`, include release highlights, compatibility and migration conditions, concrete local impact, and first-party links. Keep the recommendation and its reason in the same reply.

  ```less
  ### ❓ [tool]: [質問文]

  [調査結果]

  - **A** — 更新
  - **B** — 見送り
  - **C** — 追加説明・調査

  **推奨: [A/B/C]** — [理由]
  ```

- Use fixed uppercase choices for every decision-ready candidate: `A=更新`, `B=見送り`, `C=追加説明・調査`. Omit `A` when an update cannot be assessed safely. State the recommended letter and its reason. Accept a lowercase reply as the corresponding choice, but display uppercase letters.
- For `C`, provide the requested explanation or additional research, then ask for the same candidate's choice again before presenting another candidate. If the missing evidence cannot be obtained, explain that `A` remains unavailable and wait for `B` or new evidence; do not advance or treat `C` as update approval.
- Record each explicit selection. Do not edit sources, apply targets, test, review, or commit while any candidate choice remains open. Report candidates with no updateable difference or unresolved evidence without treating them as approved changes.

## Edit all selected updates

- After every candidate choice is settled, group selected updates by dependency. Edit the selected source changes together, including necessary configuration or invocation migrations. Do not separate dependent candidates when later isolating failures.

### Global mise tools

- Update only the selected tool's version declaration in the managed source configuration. Preserve `lazy`, `lazy_bins`, backend selection, OS and architecture conditions, installation options, and platform-specific distribution constraints.
- For HTTP declarations, update any version-specific URL, checksum, or size from the first-party artifact evidence. These are source options, not generated lock fields. Do not retain a previous release's checksum for a new version or silently substitute another distribution.
- Stage the managed global configuration and existing lock as ordinary `config.toml`, OS-specific config files, and `mise.lock` in a temporary global mise profile. Keep its HOME, XDG, mise cache, data, and state directories isolated, and run outside the repository. Read the supported targets from `settings.lockfile_platforms`; do not infer support from existing lock rows or broaden the configured scope. For ordinary version updates, regenerate only the selected tools with `mise lock --global <tool>...`. This command does not install tools; do not use `--include-lazy` to prepare an update.
- Preserve OS, architecture, and artifact variants required by the configured target scope. Generate musl artifacts with a separate `MISE_LIBC=musl` lock invocation only when musl is an explicitly supported target; do not restore retired variants merely because they appeared in an older lock. Verify the resolved artifact against the intended target before accepting the lock.
- When a separately approved platform-scope change or lock cleanup requires removing obsolete rows, use `MISE_LOCKFILE_MODE=generate mise lock --global --jobs 4` in the isolated profile. Ordinary lock refresh retains old rows. Keep full regeneration separate from routine selected-tool updates; compare tool version sets and retained URL, checksum, provenance, and signer metadata semantically, and account for every change outside the approved cleanup.
- Copy the generated lock back to its managed source path. Do not hand-edit generated URLs or checksums. Confirm declarations, version-specific source options, and resolved locks agree, and compare unselected entries with the baseline to exclude unrelated version or lock changes.
- Apply every required configuration or invocation migration in the same logical change. Do not retain compatibility aliases or old branches unless the current requirements need them.

### Distrobox images

- Replace only the selected manifest's immutable reference and synchronized version comment.
- Use the repository's existing lifecycle path for container replacement, service restart, state recording, and rollback. Do not duplicate it with an ad hoc `distrobox assemble --replace` command when chezmoi already owns that lifecycle.
- Explain interruption and rollback behavior immediately before live replacement. For Scroll, preserve its transactional next-session workflow and report a prepared candidate as pending rather than active.

## Verify once, then review and commit once

- Run one final verification phase after editing all selected updates. Within it, run the cheapest relevant static and repository checks first, then the necessary runtime checks for each affected tool or image. Fix and recheck affected work within this same phase; one phase does not mean one test command.
- For tool verification, stage the updated global configuration and lock in an isolated temporary profile outside the repository. Run `mise install` to generate bootstrap shims without eagerly installing lazy tools. Determine a version flag that does not intentionally initialize or migrate user state, invoke the selected tool's shim, and confirm the selected version and that unrelated lazy tools remain uninstalled. Retain normal auto-install behavior for required dependencies. A bare temporary HOME without the global declarations cannot resolve a shim, and repository-local config must not influence this check. If the tool has no isolatable version check, report that runtime verification as unavailable instead of executing it against the real profile.
- Capture the lock bytes before bootstrap and compare them after bootstrap and first use. Require successful first use, a byte-identical lock at both checkpoints, and zero `downloading artifact for lock-time provenance verification` messages. Use normal auto-lock behavior without `MISE_LOCKED=1`; required first-use artifact downloads are expected. Tool-presence checks alone do not establish these conditions. If the lock changes or extra provenance resolution occurs, investigate before accepting the update.
- After applying a Distrobox update, inspect the container image reference, lifecycle state files, and associated user service. Treat pending, rollback, failed, or inactive states distinctly.
- Confirm `chezmoi diff <target>` is empty after application. If a candidate still fails verification, remove the entire dependent group, including its migrations, from this commit. Restore or preserve each affected previous working target/container under the existing recovery path, then recheck the surviving changes. Report the observed state and recovery path; continue verifying independent selected updates.
- After verification, inspect the complete surviving source diff once, including shared global declarations and locks. Follow the repository's independent-review requirements and perform one independent review before committing when required.
- Commit all verified updates together in one commit under the repository's version-control requirements. If none pass, make no commit and report the state and problems. After committing passing updates, separately ask the user how to handle excluded candidates. Never push without an explicit request.

## Stop conditions

- Stop before mutation when the latest version, exact immutable image, first-party change evidence, migration, or affected source target cannot be determined reliably.
- Stop before live application when the required approval is denied or the existing rollback path is unavailable.
- Never update floating images, publish container images, modify `atty303/distrobox-image`, add dependencies, or broaden to other version sources without a separate explicit decision.
