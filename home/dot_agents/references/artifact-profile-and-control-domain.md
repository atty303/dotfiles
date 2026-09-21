# Artifact profile and control domain

## Scope and dependencies

This portable reference defines review and verification scope. It depends on [data handling](data-handling.md). Development and review workflows use it before changing durable artifacts or crossing a control boundary.

## Artifact profile

- A **spike** is a bounded hypothesis test that will not itself be released, reused, routinely operated, or depended on. A repository change is durable unless the request or repository source defines the hypothesis, end condition, and promotion condition. Do not demote an existing durable path for implementation convenience.
- A **durable** artifact is intended for release, reuse, routine operation, or operational dependence.
- A spike must still prove its hypothesis while preventing unauthorized effects, unintended data loss, secret or confidential-data leakage outside the control domain, unnecessary privacy-sensitive or personal operational identifiers in public or unrelated sinks, and unowned temporary resources.
- Promotion to durable requires reclassifying and revalidating the whole retained artifact, then applying the current mandatory-review triggers. Spike evidence does not satisfy a review that those triggers require.

## Control domain

The default trusted domain is the personal computing environment owned and managed by one user. Without an explicit mutual-distrust or isolation contract, its accounts, UIDs, root, processes, services, filesystems, local IPC, containers, and VMs are in one domain.

Trust boundaries are:

- network endpoints controlled by another subject;
- externally controlled data or executable code accepted as input or an unverified payload, even after local storage;
- accounts, credentials, or resources owned by another person, organization, or service;
- explicit multi-tenant, mutual-distrust, or guaranteed isolation boundaries; and
- a change in distribution or operating ownership that introduces a new controlling subject.

A dependency pinned and verified through the adopted process may be treated as a trusted component. Loopback and local IPC are boundaries only when reachable from outside the domain.

## Operational safety

Separate adversarial trust from operational safety. Authority, irreversibility, blast radius, data loss, recovery, partial writes, crashes, timeouts, concurrency, retries, and cleanup remain review concerns inside one trusted domain. Deliberate edits by the trusted user are not attacks absent an explicit integrity contract.

## Stop condition

Stop when artifact maturity, a controlling subject, a protected asset, or an actual boundary would materially change the review scope and cannot be established from the request, source, or operating model.
