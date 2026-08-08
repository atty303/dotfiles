---
name: maintain-agent-guidance
description: Audit, restructure, or propose durable agent guidance and reusable workflows. Use when asked to improve AGENTS.md, global guidance, repository instructions, skills, scripts, or automation, and when a completed task produces evidence-backed learning that may deserve persistence.
---

# Maintain Agent Guidance

Turn durable, evidence-backed learning into the smallest appropriate source of truth without
duplicating existing policy.

## Establish the candidate

1. Identify the behavior that should change, the scope where it should apply, and the concrete
   failure, confirmation, success, or explicit user requirement supporting it.
2. For learning discovered during another task, continue only when it is useful across future tasks
   and not obvious from an existing source of truth. Do not preserve raw failure history or
   temporary environment details.
3. Generalize evidence into applicability conditions, the correct procedure, and explicit
   prohibitions or stopping conditions.

## Route to the source of truth

Choose exactly one primary destination:

- Use global guidance for personal rules that must apply to every task even when no workflow skill
  activates.
- Use the nearest repository `AGENTS.md` for repository-specific AI conventions, commands, and
  verification requirements.
- Use source code, human documentation, an ADR, or an external system for product behavior,
  architecture, and business knowledge that matters to people as well as agents.
- Use a script, task, hook, or automation for deterministic repeated behavior; keep only its trigger
  and entry point in guidance.
- Use a personal global skill after at least two real examples establish reusable inputs, steps,
  failure conditions, stopping conditions, and verification.
- Consider a plugin only when the workflow needs distribution, multiple bundled skills, tools,
  connectors, or other plugin capabilities.

In another person's repository or an external workspace, prioritize its existing policy and the
user's authority. Persist personal guidance only when it remains appropriate outside that workspace.

## Audit and revise

1. Read the entire target file and its applicable parent guidance before proposing or editing it.
2. Prefer integrating, replacing, simplifying, or deleting existing text over appending another
   rule.
3. Record each rule once. Move detailed procedures, examples, and reference material into the
   selected skill, script, or documentation source.
4. Do not add information that changes no behavior, is easily discoverable from its canonical
   source, or records a one-time decision.
5. Propose a broader inventory only when the audit reveals duplication, contradiction, staleness,
   overly long procedures, or unclear scope. Judge by information density and applicability, not a
   fixed length.

## Produce or apply the result

- When reporting a learning candidate, provide its destination, evidence, rationale, and exact
  proposed addition, replacement, or deletion. Do not apply it without approval.
- When the user explicitly requests a guidance change, implement it in the appropriate source state,
  respecting dotfile management and repository version-control rules.
- For a skill candidate, specify its purpose, trigger, inputs, outputs, steps, failure conditions,
  stopping conditions, verification, and installation scope.
- Keep each skill focused on one recognizable goal. Start instruction-only; add references for
  detailed policy and scripts only for deterministic or repeatedly rewritten operations.

## Verify

- Confirm the new rule is discoverable at the intended scope and does not conflict with closer
  guidance.
- Validate skills with the skill validator and test direct, indirect, incomplete, negative, and
  edge-case prompts when activation behavior changes.
- Test any bundled script with representative inputs and failure cases.
- Review the rendered dotfile diff before applying only the affected target, then confirm the target
  diff is empty.
- Commit an approved guidance update separately from the task that produced the learning.
