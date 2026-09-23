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

## Check version differences before research

- The parent agent performs a lightweight version comparison for every in-scope source before dispatching research. Use `mise latest <tool>` for tool versions and published image metadata for immutable references. Record the current and newest available versions or references, plus any obvious lock inconsistency. Do not perform release-by-release research or edit sources in this pass.
- An exact mise stub with embedded lock URLs for another version remains a candidate for regeneration even without a version bump. Report declared, locked, and installed versions separately when investigating it.
- For Distrobox, compare available published immutable references with the current manifest and check the latest upstream application release separately. If upstream is newer but no newer immutable image is available, report that briefly; do not start a subagent solely for that gap.
- Dispatch each candidate with an available version, lock, or immutable-reference change to its own read-only subagent. Run these investigations concurrently up to the available agent slots; queue the remainder. Give each subagent the source, current and candidate versions or references, and the research requirements below. The parent owns user decisions and all mutations.

## Investigate each candidate

Each candidate subagent completes the applicable checks below before returning a decision-ready report. If subagent execution is unavailable, stop and report which candidates remain uninvestigated; do not silently switch to a lighter investigation.

### Mise tool stubs

- Read `tool` and `version` from each source stub. Treat the stub filename as the command name; do not assume it matches the mise tool identifier.
- Verify the latest stable release with `mise latest <tool>`. Do not constrain the major version.
- When the current version is a prerelease, also identify the newest release in the same prerelease channel, but keep the latest stable release as the primary candidate.
- For an inconsistent exact stub, research changes from the oldest artifact that a fresh installation could resolve through the candidate version.

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

- Ask every user-facing question in this workflow in an ordinary assistant reply, not through `AskQuestion`, `AskUserQuestion`, or another question tool. This includes candidate choices, follow-up questions after `C`, and post-commit questions about excluded candidates. Keep the required per-target elevated execution approval for `chezmoi apply`.
- As subagent reports arrive, the parent presents one decision-ready candidate at a time and waits for its answer. In the same reply, present the release highlights, compatibility and migration conditions, concrete local impact, first-party links, recommendation and rationale, and the choices below. Queue other completed reports while awaiting a response; do not wait for every investigation to finish before asking the first question.
- Use fixed uppercase choices for every decision-ready candidate: `A=更新`, `B=見送り`, `C=追加説明・調査`. Omit `A` when an update cannot be assessed safely. State the recommended letter and its reason. Accept a lowercase reply as the corresponding choice, but display uppercase letters.
- For `C`, provide the requested explanation or additional research, then ask for the same candidate's choice again before presenting another candidate. If the missing evidence cannot be obtained, explain that `A` remains unavailable and wait for `B` or new evidence; do not advance or treat `C` as update approval.
- Record each explicit selection. Do not edit sources, apply targets, test, review, or commit while any candidate choice remains open. Report candidates with no updateable difference or unresolved evidence without treating them as approved changes.

## Edit all selected updates

- After every candidate choice is settled, group selected updates by dependency. Edit the selected source changes together, including necessary configuration or invocation migrations. Do not separate dependent candidates when later isolating failures.

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

## Verify once, then review and commit once

- Run one final verification phase after editing all selected updates. Within it, run the cheapest relevant static and repository checks first, then the necessary runtime checks for each affected tool or image. Fix and recheck affected work within this same phase; one phase does not mean one test command.
- Run `chezmoi diff <target>` before applying. For each exact target, request approval and run `chezmoi apply <target>` with elevated sandbox permission; never request a permanent approval or apply without a target.
- After applying a tool stub, determine a version flag that does not intentionally initialize or migrate user state, run it from a temporary working directory outside the source repository with temporary `HOME` and XDG directories, and confirm it reports the selected version. A repository-local `mise.toml` can otherwise require trust in the temporary profile and fail before the tool executes; do not mutate trust state merely to make the check pass. If the tool has no isolatable version check, report that runtime verification as unavailable instead of executing it against the real profile.
- After applying a Distrobox update, inspect the container image reference, lifecycle state files, and associated user service. Treat pending, rollback, failed, or inactive states distinctly.
- Confirm `chezmoi diff <target>` is empty after application. If a candidate still fails verification, remove the entire dependent group, including its migrations, from this commit. Restore or preserve each affected previous working target/container under the existing recovery path, then recheck the surviving changes. Report the observed state and recovery path; continue verifying independent selected updates.
- After verification, inspect the complete surviving source diff once. A fresh independent review is not required when that complete diff is limited to one mise tool stub regenerated with the required `mise generate tool-stub ... --lock --version <exact-version>` command. Still complete every static, lock-consistency, chezmoi, and isolated runtime verification required by this skill.
- Follow the repository's independent-review requirements when the surviving change also includes a configuration or invocation migration, another source file, a hand-edited generated field, or a Distrobox image update. If required, perform one independent review of the complete surviving diff before committing.
- Commit all verified updates together in one commit under the repository's version-control requirements. If none pass, make no commit and report the state and problems. After committing passing updates, separately ask the user how to handle excluded candidates. Never push without an explicit request.

## Stop conditions

- Stop before mutation when the latest version, exact immutable image, first-party change evidence, migration, or affected source target cannot be determined reliably.
- Stop before live application when the required approval is denied or the existing rollback path is unavailable.
- Never update floating images, publish container images, modify `atty303/distrobox-image`, add dependencies, or broaden to other version sources without a separate explicit decision.
