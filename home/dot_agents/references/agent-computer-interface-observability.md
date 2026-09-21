# Agent-Computer Interface program observability contract

Status: Living Standard  
Last updated: 2026-09-22

## Scope and dependencies

This portable contract is the canonical observability source for programs developed by agents. It depends on [data handling](data-handling.md) and [failure oracle and causal verification](failure-oracle-and-causal-verification.md). Repository-specific policy takes precedence.

The goal is to retain bounded evidence from normal use so an agent can inspect the actual run before reproducing a problem or adding temporary logs. OpenTelemetry's domain model and Semantic Conventions are preferred vocabulary, but no OTel SDK, OTLP, Collector, backend, or common wire format is required. Compiler, test runner, VCS, sandbox, GUI tools, and the rest of the coding-agent interface are outside this contract except as artifacts linked to a program run.

`MUST` is required for an applicable path; `SHOULD` requires an equivalent justification when omitted; `MAY` is optional.

## Applicability

An independent observation surface is required when a path includes any of:

- network, filesystem, database, credential store, external process, device, or runtime boundary;
- mutation of user data, configuration, or an external resource;
- async, concurrency, queue, worker, retry, timeout, or cancellation;
- multiple stages where different failures produce the same final symptom; or
- timing, external state, or environment that makes reproduction difficult.

Distribution form and implementation size do not decide applicability. A path may omit independent observation only when it is short, synchronous, deterministic, preserves failure in a typed error, exit status, or public interface, identifies the failed operation and cause uniquely, and can be rerun safely and cheaply from the same input without retained evidence.

Applications own enablement, recording, retention, deletion, and export. A library MUST NOT configure an SDK, global provider, exporter, or store; it uses a host-provided provider, context, or diagnostic sink and works without a consumer.

## Separate interfaces

Keep three surfaces distinct:

| Surface | Responsibility |
| --- | --- |
| Result | requested stdout, API response, file, or UI result |
| Control | invocation, cancellation, and result judgment such as arguments, API, or exit status |
| Observation | causal operations, events, error types, and artifact references |

Do not turn public stdout, stderr, API responses, or UI into agent diagnostic transport. User-facing errors explain impact and recovery; a stable diagnostic run ID may correlate them with the observation surface. Observe the normal result path, not a diagnostic-only substitute.

## Semantic model

- **Diagnostic Run** identifies one user action, invocation, request, job, or investigated execution. Its stable ID correlates operations, events, artifacts, and user-visible diagnostic IDs across processes when practical. Mark completeness `complete`, `partial`, or `dropped`; for incomplete runs record the known reason and range. A missing non-atomic completion marker means `partial`. If the run cannot be stored, expose recording-subsystem degradation. Missing evidence never proves an event absent.
- **Resource** identifies at least program or service and version, plus runtime, OS, architecture, environment, process, or build only when diagnostic value warrants it.
- **Operation** is a named, timed stage with status and parent or link. Instrument external boundaries, mutations, retry/timeout ownership, and stages needed to distinguish failure. Use stable low-cardinality names, never input values or one operation per function.
- **Event** is a causally important point such as a state transition, retry, fallback, or signal. It is not a stream of debug prose or a duplicate exception.
- **Status and Error Type** distinguish at least success, error, cancellation, and timeout. A stable machine-readable error type such as `permission_denied` or `schema_invalid` identifies class; messages, bodies, paths, inputs, and dynamic IDs do not. Reuse an applicable OTel convention.
- **Context and Link** propagate run and operation identity across thread, async, queue, process, and runtime boundaries. Links represent retry, fan-out, batch, producer/consumer, and non-parental relationships. Context MUST NOT transport credentials or arbitrary user data.
- **Artifact** references evidence too large or unsuitable for attributes: screenshot, video, DOM or state snapshot, structured test result, redacted shape, generated output, or core dump. Associate kind, producer operation, time, location, schema/format, retention, and classification. Artifact existence alone is not success.
- **Attribute** is an allowlisted structured value with defined meaning, unit, cardinality, necessity, and classification. Reuse conventions and avoid synonyms.

## Error and causal contract

Telemetry never replaces typed errors, Results, exception causes, exit status, or caller contracts. Lower layers preserve cause. The operation owner records a failure and error type once. Do not duplicate the same exception across layers. A recovered retry or fallback is not final failure; intentional cancellation is neither error nor timeout; recording failure is not product-operation failure.

Apply [failure oracle and causal verification](failure-oracle-and-causal-verification.md): retained evidence is primary but does not itself prove causation involving unrecorded input, timing, or external state.

## Recording and user control

Applicable programs MUST enable instrumentation and bounded local recording by default with an opt-out. Remote export to another process-owned remote destination, machine, service, or cloud is a separate explicit opt-in and defaults off.

When recording is disabled, save no records and perform no work beyond minimal no-op instrumentation. Except for observation records and their management state, result, control, exit status, durable state, and external effects stay equivalent.

- A short-lived process records one run in a bounded buffer and retains recent successful runs for a bounded grace period or count because a user may later identify wrong output, a missing effect, or incorrect UI. Immediate discard is allowed only when the user can reliably judge and freeze before exit. Prefer error, timeout, crash, and user-marked runs; bound shutdown flush.
- A resident process uses a time- or capacity-bounded rolling buffer, evicts old success first, and can freeze a reported run plus required surrounding context.

Each application defines and exposes enablement/opt-out, store and permissions, capacity or duration, success/failure/frozen eviction, listing, deletion, safe export, and any remote destination, fields, and opt-in.

## Data and privacy

Apply [data handling](data-handling.md) at instrumentation time through source allowlists; downstream filtering is defense in depth, not a replacement. Raw or recoverable credentials never enter records or artifacts. Credential kind, key ID, or expiry may be allowlisted when it cannot recover or test the value.

Record bodies, clipboard, input text, conversations, screens, personal files, full URLs, command lines, environment, exceptions, or stack traces only as individually classified fields whose necessity and safe representation are defined. Authorized local diagnostics may retain necessary operational identifiers; remote export and public artifacts minimize unnecessary person- or host-specific values. Stored records and artifacts are user data with least permission, bounded retention, and deletion. Agents read only runs needed for the authorized investigation and do not send them to unrelated services.

## Non-interference and bounds

- Consumer absence, opt-out, capacity exhaustion, store failure, or exporter failure MUST NOT change the product result.
- Bound observation queue, buffer, flush, shutdown, retry, memory, disk, and time. Expose degradation or completeness without recursive failure loops.
- Compute expensive attributes or artifacts only after deciding to record them.
- Measure enabled-path cost where latency, timing, or resource limits matter. Reduce normal-run volume with bounded buffers or tail selection; do not randomly sample away failures.

## Conformance

Test only scenarios reachable from the changed path, but cover each applicable contract:

- program-detected failure can be retrieved by run, resource, failed operation/stage, error type, and artifact;
- a user-reported success run retains completeness, operation tree, final status, artifacts, and the fact the program saw no failure;
- opt-out preserves public behavior and effects while saving no record;
- recording/export failure or absent consumer does not change the product operation;
- partial/drop exposes degradation, reason, and known missing range;
- no configured remote means no remote diagnostic transmission;
- async/retry preserves parent, link, attempt, and final-result distinctions;
- timeout, cancellation, and crash are distinct, with pre-crash buffer retained when practical;
- classified fixtures contain no raw/recoverable secret and obey destination-specific allowlists and minimization;
- an excluded deterministic path satisfies every exclusion condition; and
- an instrumented library leaves provider, consumer, exporter, and storage ownership to its host.

Use public-behavior comparison, store-failure injection, privacy fixtures, async links, failure retention, retention bounds, and deletion tests as applicable. Report any boundary verifiable only in a target environment.

## Non-goals and derived guidance

This contract does not require universal OTel infrastructure, every function as an operation, every telemetry signal, replacement of typed errors or user messages, default remote telemetry, verbose public diagnostics, removal of reproduction or regression tests, or a wire format for the whole Agent-Computer Interface.

AGENTS and skills SHOULD reference this source and retain only workflow-specific triggers, actions, handoffs, and stop conditions. A derived-guidance change requires realistic forward tests.
