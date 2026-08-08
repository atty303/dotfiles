# atty303 Engineering Policy

Apply this policy after any closer repository-specific guidance.

## Implementation Style

- Prefer types that make invalid states unrepresentable, pure functions, immutable data, and
  exhaustive branching.
- When technology selection is open, prefer an expressive static type system and functional
  representations.
- Do not reject an abstraction merely because it is advanced or less familiar. Adopt it when it
  materially reduces implementation size or duplication, or improves changeability.

## Comments

- Express intent through types, names, and code structure before adding comments.
- Record only design intent, constraints, invariants, and external circumstances that cannot be
  derived from the code. Do not paraphrase behavior.
- In public API documentation, document only contracts, side effects, error conditions, and units
  that the type cannot express.

## Documentation

- Keep the README focused on overview, setup, and primary operations. Add detailed reference
  documentation only for features that need it.
- Document internal design only when the rationale, alternatives, constraints, or invariants are not
  evident from the code.
- Keep design information near the relevant source when natural. Use an ADR for long-lived decisions
  spanning multiple areas.
- Do not rewrite an accepted ADR. Record a policy change in a new ADR that identifies the superseded
  decision.
- Match the existing documentation language and audience; use English when neither is clear.
- Update an existing changelog or release-note process only; do not introduce a new history
  mechanism automatically.
- Update or remove documentation made stale by implementation changes in the same logical change.

## Single Source of Truth

- Establish one source of truth for each concept where practical and derive types, configuration,
  code, and other representations from it.
- Link README files, design documents, and comments to the source of truth or generate them from it.
- Allow duplication when eliminating it would add disproportionate complexity or coupling. If drift
  remains a risk, enforce synchronization with static checks or automated verification.
- Do not commit generated artifacts by default. Lockfiles required for reproducibility are the
  exception. Regenerate artifacts through `mise`.

## Testing Strategy

- Do not duplicate guarantees already provided by type checking or static analysis in dynamic tests.
- Limit unit tests to important logic that static checks cannot guarantee. Do not add tests solely
  for trivial functions, thin delegation, implementation details, or coverage metrics.
- Prefer a small number of property-based tests over many examples when invariants or transformation
  laws can be expressed.
- Test boundaries such as external APIs, databases, files, and protocols with integration tests when
  needed.
- Use `mise run check` as the shared entry point for static checks, lightweight tests, link checks,
  generated-diff checks, doctests, and feasible command or code-example validation. Run the same
  task locally and in CI; keep heavy or externally dependent verification separate.
- Protect high-value user flows and catastrophic-failure paths with E2E tests. Keep E2E outside
  `mise run check` and run it for important-flow changes, cross-boundary changes, release
  preparation, or serious regression risk.
- When a bug becomes unrepresentable through types or design, a regression test is optional. Add one
  only when a meaningful recurrence risk remains dynamically observable.

## Reproducibility

- Ensure committed code and scripts can prepare dependencies and run on a host where only `mise` is
  preinstalled.
- Manage required runtimes, tools, dependencies, and tasks with `mise`.
- Host tools may be used for temporary work, but committed artifacts must not depend on them.
- Ask before proceeding when this policy cannot be satisfied.
- Commit `mise` and package-manager lockfiles by default.
- Include `mise` configuration, lockfiles, `mise run check`, and CI integration in a new
  repository's initial setup.
- If an existing repository does not comply, establish only the infrastructure required to perform,
  verify, or reproduce the requested change. Otherwise leave it unchanged and report the gap.
