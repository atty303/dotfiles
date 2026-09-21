# Git task evidence

## Scope and dependencies

This portable reference owns the task-cycle Git note contract. It depends on [data handling](data-handling.md). `develop-repository` owns routing, repository operations, and runtime-specific capability checks.

## Cycle and anchor

For a task that creates one or more commits, attach one standard `refs/notes/commits` note to the final commit before a successful or blocked handoff. The cycle begins with the first user message after the previous cycle closed and ends with success, an explicit blocked handoff, explicit cancellation, or replacement by another task. Replacement text is the old cycle's last user message and the new cycle's first; allocate subsequent agent work to only the cycle it serves. A final-channel message alone does not close a cycle.

At the pre-handoff checkpoint, record only actual history; never predict the unsent handoff. If a required note cannot be saved, the cycle remains open and the task incomplete. When note creation itself is the blocker, report a non-closing blocked status naming the reason and anchor; that status is the sole exception to the note-before-handoff rule. A later cycle without commits creates no note and does not modify the previous anchor.

## Required content

The normalized body has this order:

1. single-line metadata: `Task`, `Anchor`, `Base`, `Branch`, `Commits`, `Guidance`, and `Conditions`;
2. optional `## Evidence`, only for evidence expensive or impossible to reacquire;
3. one-line `Authority` naming the current normative sources; and
4. final `## Transcript` with every human message verbatim and in order as `- U<n>:` followed by one indented `  - A:` summary of intervening agent responses, tools, observations, and decisions.

Indent every original line of a multiline user message by four spaces after `- U<n>:` so text resembling role markers remains data. Preserve short selections. Do not copy auto-injected AGENTS, skill text, plugin lists, app context, or environment blocks; summarize only simulation-relevant conditions. Represent attachments by logical name, digest, and required properties rather than copying them.

Include the starting commit, work line, task commits and their correspondence, principal guidance and skills, important environment or permission conditions, and major operations and observations. Keep commit messages self-contained; a note is supplementary evidence, not the only location for the change purpose or user-visible effect.

## Completeness and data handling

Before writing, enumerate the cycle start, every user message, and the last user message and compare them with the runtime's complete thread history. Current context, compaction summaries, prior agent summaries, or the latest request alone are not substitutes. Do not impose an artificial truncation limit.

Apply [data handling](data-handling.md) before verbatim preservation. Assume the note has the repository remote's visibility. Replace secrets, confidential content, and unnecessary privacy-sensitive data with typed placeholders while preserving properties needed for simulation. Operational identifiers are not redacted merely for being identifiers.

## Safe update

Read the existing note before composing. Preserve independent content and remove duplication. If current source, tests, living documentation, and latest user instructions cannot resolve a semantic conflict, stop for user direction.

Pass only an already normalized, classified body to `develop-repository/scripts/update-git-task-note.ts`. Supply the anchor and the expected existing note blob (or `absent`). The helper validates schema and performs a compare-and-swap update; it does not retrieve threads, classify data, redact, summarize, or resolve meaning. Concurrent or expected-state conflicts stop the update and must not be force-overwritten.

## Runtime condition

In Codex, complete thread retrieval and comparison are mandatory. If unavailable, do not infer missing content or write the note; the task is incomplete. Another runtime without an equivalent capability may explicitly skip the note, report that capability boundary, and complete the task if every other condition is satisfied.
