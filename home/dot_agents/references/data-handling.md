# Data handling

## Scope and dependencies

This portable reference classifies data by capability, explicit confidentiality contract, and destination. It has no reference dependencies. Development, review, observability, Git evidence, and external-service workflows use it when they handle non-public data.

## Classification

- **Secret**: a value whose possession enables authentication, authorization, decryption, signing, or impersonation, including passwords, private keys, access or refresh tokens, session cookies, authentication headers, credential-bearing URLs, and signed URLs. Never display, record, or commit a raw or recoverable secret, and never transmit one except to its authorized intended authentication endpoint.
- **Confidential content**: text or data declared non-public by a user, repository, contract, or data owner. Process only what the authorized task requires; do not send it to unrelated services, public artifacts, or logs.
- **Privacy-sensitive data**: names, email, addresses, location, behavior history, conversations, screens, and personal-file contents. It is not automatically secret. Use it when necessary on an authorized task surface, but minimize unnecessary values in public or unrelated external sinks.
- **Operational identifier**: home paths including usernames, hostnames, account names, IPs, PIDs, ports, device names, repository paths, UUIDs, digests, and commit IDs. Absent another contract these are not secrets and may be retained in authorized diagnostics. Minimize unnecessary person- or host-specific values in public artifacts for privacy or portability.

Retain diagnostically necessary information by default in program instrumentation, investigation commands, and error reports. Restrict a value only on concrete evidence of credential form, an authentication field, conferred capability, an explicit confidentiality contract, or a privacy requirement for the actual third-party recipient or public audience. Do not classify from entropy, length, private permissions, a username in a path, environment specificity, or the word `token` alone. Unknown text does not need proof of safety before retention; the residual risk of an undetected secret does not justify blanket suppression.

Mask the identified secret value or protected portion and preserve the remaining message, effective values, and causal context. Do not redact an entire stderr stream, exception, line, or field merely because it might contain a secret. A field that consists entirely of a secret is masked in full.

## Sink rules

- Select information by task and diagnostic relevance, not by a requirement to prove every value safe. For auth, IAM, OAuth, or service responses, mask known credential fields and values before tool output while preserving necessary non-secret content.
- Command lines, URL queries, bodies, environment, stderr, exceptions, stack traces, conversations, screens, clipboard, and personal files are containers. Apply protection to identified portions, including within unstructured text; do not require exhaustive field extraction or classification before retaining the rest. This does not require whole-environment dumps or unlimited recording.
- Judge disclosure by the actual recipient and access contract, not by local versus remote placement. User-managed accounts and resources, including CloudWatch in the user's AWS account, are within the control domain; an external service provider alone does not make them third-party destinations. A user-owned public log is third-party disclosure because of its audience.
- Where a path actually sends or publishes to a third party, restrict only the specific secrets, confidential content, or unnecessary personal information that must not be shared, preserving the remaining diagnostic evidence. Do not suppress an entire output because it has a third-party destination. These rules do not authorize a new transmission, publication, destination, or permission; known secrets remain masked in diagnostics inside the control domain too.
- Hashing is not automatically anonymization. Use a fingerprint only when its input space and comparison use cannot recover or test the protected value.
- Prefer an existing agent actor or identity boundary and short-lived least-privilege credentials for new authentication paths. Do not create a route to fixed, long-lived, or human credentials merely to unblock an agent.
- On authorization failure, do not change identity, credential, IAM policy, role, permission boundary, profile, or scope unless IAM management is itself authorized. Report the failed action and resource and stop. Sandbox or network approval and use of a configured connector within its existing authority are separate.

## Stop condition

Stop an unauthorized transmission or publication, or the affected disclosure when a concrete protection contract cannot be satisfied. Do not stop ordinary authorized recording or investigation, suppress unknown diagnostic text, or require user confirmation solely because a secret might be present. If a necessary disclosure depends on unresolved destination access or authority, resolve that boundary before sending; retain the diagnostic evidence with identified secrets masked in the meantime.
