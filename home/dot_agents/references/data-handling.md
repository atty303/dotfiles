# Data handling

## Scope and dependencies

This portable reference classifies data by capability, explicit confidentiality contract, and destination. It has no reference dependencies. Development, review, observability, Git evidence, and external-service workflows use it when they handle non-public data.

## Classification

- **Secret**: a value whose possession enables authentication, authorization, decryption, signing, or impersonation, including passwords, private keys, access or refresh tokens, session cookies, authentication headers, credential-bearing URLs, and signed URLs. Never display, record, or commit a raw or recoverable secret, and never transmit one except to its authorized intended authentication endpoint.
- **Confidential content**: text or data declared non-public by a user, repository, contract, or data owner. Process only what the authorized task requires; do not send it to unrelated services, public artifacts, or logs.
- **Privacy-sensitive data**: names, email, addresses, location, behavior history, conversations, screens, and personal-file contents. It is not automatically secret. Use it when necessary on an authorized task surface, but minimize unnecessary values in public or unrelated external sinks.
- **Operational identifier**: home paths including usernames, hostnames, account names, IPs, PIDs, ports, device names, repository paths, UUIDs, digests, and commit IDs. Absent another contract these are not secrets and may be retained in authorized local diagnostics. Minimize unnecessary person- or host-specific values in public artifacts for privacy or portability.

Do not classify from entropy, length, private permissions, a username in a path, or environment specificity alone. Use credential form, auth field, conferred capability, and explicit contract. Until ambiguous data is classified, do not repeat its raw value.

## Sink rules

- Filter at acquisition: when querying auth, IAM, OAuth, or external-service configuration, allowlist required non-secret fields before tool output; never print a raw response that may contain credentials.
- Treat command lines, URL queries, request or response bodies, environment, exception text, stack traces, conversations, screens, clipboard, and personal files as containers requiring field-by-field classification, not as safe or unsafe wholesale.
- Hashing is not automatically anonymization. Use a fingerprint only when its input space and comparison use cannot recover or test the protected value.
- Prefer an existing agent actor or identity boundary and short-lived least-privilege credentials for new authentication paths. Do not create a route to fixed, long-lived, or human credentials merely to unblock an agent.
- On authorization failure, do not change identity, credential, IAM policy, role, permission boundary, profile, or scope unless IAM management is itself authorized. Report the failed action and resource and stop. Sandbox or network approval and use of a configured connector within its existing authority are separate.

## Stop condition

Stop before exposing or moving data when its class, destination, task authority, or minimum necessary representation cannot be established.
