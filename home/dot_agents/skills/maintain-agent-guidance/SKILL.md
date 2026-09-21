---
name: maintain-agent-guidance
description: AGENTS、skill、agent guidance、永続化規則または過去taskの学びの保存・整理・監査をユーザーが明示的に依頼した場合に、候補を検証し適切な原典への変更を提案する。
---

# Maintain agent guidance

Use this workflow only for an explicit user request to preserve, organize, compress, or audit agent guidance or learnings. Do not run it as an automatic task-completion or development checkpoint.

## Treat evidence correctly

- Codex memory is a falsifiable descriptive hypothesis cache, not a policy or knowledge source. Session logs are primary historical evidence but do not prove causality; verify claims with source, tests, or live observation.
- AGENTS, global guidance, skills, scripts, automations, and domain sources contain adopted normative rules. They override memory as behavior guidance. Do not edit generated memory directly; report a correction candidate unless the user separately authorizes the memory control.
- Deterministic defects inside the authorized scope belong in the nearest source, test, task, build process, or runtime workflow, not in a deferred learning proposal.
- Do not auto-promote a candidate. Propose its destination, evidence, reason, exact change, positive case, near-miss, and stop condition. Apply it only after approval as a separate logical change.

## Validate candidates

For each candidate:

1. State the generalized hypothesis rather than copying a success or failure.
2. Attribute the cause to source, test harness, task/build, workflow trigger, runtime, external condition, agent error, stale memory, normative user choice, or unknown.
3. Seek contrary and control cases; a success does not prove an operation was necessary.
4. Bound scope to personal global, repository, OS, version, tool, or one task.
5. Check whether the nearest source, test, guidance, skill, or script already resolves it.
6. Classify it as `promote`, `retain as hypothesis`, `needs validation`, `contradicted`, `already resolved`, or `one-off/no persistence`.

Ordinary workflow rules and tool preferences require multiple independent cases or a reproduction and counterexample. An explicit personal preference may be globally proposed after scope and conflicts are checked. A high-impact authority or safety policy may rest on one explicit decision. A repository specification may rest on current source or tests.

## Audit multiple sessions only when requested

- For an explicit cross-session or memory audit, run `scripts/collect-session-evidence.ts` against completed root sessions. Exclude the current audit, subagents, incomplete sessions, duplicates, read-only external-service lookups, and general consultations.
- Follow the requested range. Without one, inspect up to 25 development root sessions from the last seven days, oldest first, continuing batches while eligible sessions remain.
- Use memory only as an index and trace every claim to a session log or other primary evidence. A session with parse warnings, redacted messages, truncation, or omissions is incomplete; narrow the extraction or corroborate it before promotion.
- Keep the audit read-only. Report coverage, evaluated session IDs, remaining count, rejection totals by reason, and at most five candidates with evidence, counterexamples, attribution, confidence, scope, current-guidance relation, destination, forward test, and exploration lost by a false generalization.

## Route to the nearest owner

- Put human-facing specifications and design knowledge in source or documentation; repository-specific agent behavior in the nearest AGENTS; personal cross-task policy in global guidance; reusable workflows in skills; and deterministic repeated operations in scripts, tasks, or automations.
- A reusable personal skill requires at least two examples establishing inputs, outputs, procedure, failures, stop conditions, and verification. Keep repository values out of the workflow and consider a plugin only when distribution is needed.
- For every target file, prefer integration, replacement, simplification, and deletion over appending. Do not duplicate a rule that was merely skipped; repair its reachable trigger or mechanically enforce it at the nearest owner.
- Do not preserve discoverable facts, behavior-neutral information, one-off reasoning, historical narrative, or content already owned by a closer source. Propose a broad inventory only when evidence shows duplication, contradiction, staleness, long procedures, or unclear scope.
