# Failure oracle and causal verification

## Scope and dependencies

This portable reference defines evidence for investigation, development, review, and observability. It has no reference dependencies.

## Contract

- Fix the user-observable final state that distinguishes success from failure as the **failure oracle** before changing code. A request start, redirect, initial render, intermediate state, local symptom disappearance, or success under different conditions is not a substitute.
- Separate observations, hypotheses, inferences, and unknowns. Treat a proposed cause or fix from any person, model knowledge, memory, or analogous case as a falsifiable prior until evidence establishes it.
- Establish the causal chain from the violated invariant through the changed production path to the oracle. Test the actual caller, dispatcher, consumer, and state transitions whose reachability or meaning changed. A test that directly creates a downstream success state proves only the boundary before it.
- Preserve one-factor comparisons where practical. A workaround that makes the oracle pass is not proof that the cause was removed. A post-change success can confirm the normal path but cannot by itself establish the original root cause.
- Re-evaluate newly reachable downstream states, semantic conversions, retry, re-entry, cancellation, and inverse operations. Do not expand into unrelated code when the change cannot affect its reachability or meaning.
- If the target environment cannot be exercised, distinguish verified implementation boundaries from an unverified final oracle. Human confirmation is an exception when the agent cannot observe the required boundary.

## Stop condition

Do not claim root cause, repair, or completion while the oracle, causal chain, or a changed boundary remains unobserved. Report the evidence, uncertainty, and next discriminating observation instead.
