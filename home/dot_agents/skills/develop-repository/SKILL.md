---
name: develop-repository
description: Implement, fix, refactor, or review changes in a local software repository using the user's repository-discovery, engineering-policy, verification, documentation, and delivery workflow. Use for development tasks that may modify source code, tests, configuration, documentation, or build infrastructure in an atty303 or third-party repository.
---

# Develop a Repository

Carry a repository change from discovery through local delivery while preserving repository-specific
rules and unrelated user work.

## Establish the repository context

1. Read the applicable repository guidance and inspect the relevant entry points, configuration,
   manifests, tasks, and documentation before deciding how to change the repository.
2. Determine whether the repository uses `jj`; use `jj` for writes when `.jj` exists and otherwise
   use `git`.
3. Inspect the working state before editing. Treat pre-existing and unrelated changes as user-owned
   and keep them out of the completed change.
4. Determine the GitHub owner from `origin`. If `origin` is missing or inconclusive, infer `atty303`
   or Other from the repository location, purpose, and request context. Ask only when the remaining
   ambiguity changes the applicable policy.

## Select the engineering policy

- For an `atty303` repository, read
  [references/atty303-engineering-policy.md](references/atty303-engineering-policy.md) completely
  and apply all of it after closer repository guidance.
- For an Other repository, prioritize its own policies. Where they are silent, read the same
  reference and use only its Implementation Style, Comments, and Testing Strategy sections as design
  preferences.
- Do not introduce `mise`, CI, or other development infrastructure into an Other repository merely
  to match the `atty303` policy. Add it only when required to complete or verify the requested
  change.

## Implement the change

1. Keep the change within the requested repository unless the user explicitly expands the scope.
2. Prefer the repository's existing abstractions and sources of truth. Update derived
   representations from their source instead of maintaining parallel definitions where practical.
3. Update related user documentation when behavior, CLI, configuration, or a public API changes.
   Update an existing changelog or release-note mechanism only when the repository already uses one.
4. Avoid leaving documentation or comments that are made stale by the implementation.

## Verify and deliver

1. Run the relevant tests, lint, type checks, and build in proportion to the change. Use the
   repository's documented task entry points.
2. For an `atty303` repository, use `mise run check` as the common lightweight verification entry
   point when it exists or when the task requires establishing the repository's mandated baseline.
   Run separate E2E or external-dependency tasks when the changed flow or risk warrants them.
3. Report every required verification that could not be run and its reason.
4. Review the final diff, include only this task's changes, and create one or more focused local
   commits or changes according to the repository convention.
5. Report the change summary, completed verification, and any unresolved or unexecuted items
   concisely.
6. Evaluate durable learning under the global guidance. Invoke `$maintain-agent-guidance` only when
   a supported candidate exists.
