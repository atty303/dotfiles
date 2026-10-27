# Git task evidence

## Scope and dependencies

This portable reference owns task-cycle evidence in commit messages. It depends on [data handling](data-handling.md). `develop-repository` owns repository operations and runtime-specific capability checks.

## Cycle and checkpoint

For a task that creates one or more commits, put the complete task transcript in the final commit message. Each commit must explain its own change without relying on the transcript. The cycle begins with the first user message after the previous cycle closed and ends with success, an explicit blocked handoff, explicit cancellation, or replacement by another task. Replacement text is the old cycle's last user message and the new cycle's first; allocate subsequent agent work to only the cycle it serves. A final-channel message alone does not close a cycle. A later cycle without commits does not modify earlier commit messages.

Freeze the record immediately before creating the final commit. Include only actual history through that checkpoint; never predict commit or push results or the unsent handoff. Report subsequent commit and push results in the final response, and do not amend solely to extend the record. If required history cannot be obtained and checked, defer the final commit and report the blocker; the task remains incomplete.

## Message content

Use this order:

1. the ordinary commit subject and self-contained change explanation;
2. optional `## Evidence`, only for evidence expensive or impossible to reacquire;
3. `## Transcript`, with every human message verbatim and in order as `- U<n>:` followed by one indented `  - A:` summary of intervening agent responses, tools, observations, and decisions; and
4. repository-required commit trailers, including the applicable co-author trailer.

Put each `- U<n>:` marker on its own line and prefix every original user-message line, including empty lines, with four spaces and `> `. Removing that exact prefix must recover the original message. Preserve multiline structure and short selections. Prefix continuation lines of agent summaries the same way. Whitespace indentation alone can still be parsed as a breaking-change footer by Conventional Commit tooling; the quote marker keeps such lines as transcript data. Keep role markers and trailers inside the quoted text as data as well. Do not copy auto-injected AGENTS, skill text, plugin lists, app context, or environment blocks; summarize only conditions relevant to understanding or analyzing the task. Represent attachments by logical name, digest, and required properties rather than copying them.

Include important environment, constraints, decisions, operations, observations, and verification limits in the change explanation or agent summaries. Do not require fixed `Task`, `Anchor`, `Base`, `Branch`, `Commits`, `Guidance`, `Conditions`, or `Authority` metadata or repeat information merely because Git exposes it.

### Dig selections

Only for a selection response to a dig question, supplement the original human message with `  - Selection: Q<n> / <label>` between its quoted text and the `  - A:` summary. Quote the selected option's body exactly as presented, including continuation lines, with the same `    > ` prefix. This is assistant-sourced context, not human speech; preserve the original response separately even when it is only `a` or `b`. Apply the same data handling to the copied option text.

Resolve the question and selected label from the complete thread's actual question and response. A reply with added qualifications still retains those qualifications in the original human message. Do not infer a selection from the recommendation, a similar option, or a missing question. If the correspondence is ambiguous or unavailable, preserve the response and describe that limitation in the agent summary instead of fabricating a `Selection` entry. Do not apply this exception to selections outside dig or copy all unselected options.

## Completeness and data handling

Before saving, enumerate the cycle start, every user message, and the last user message and compare them with the retrieved thread history under the runtime condition below. Current context, compaction summaries, prior agent summaries, or the latest request alone are not substitutes. Do not impose a line or character limit or truncate long transcripts. The complete human messages support later analysis of how to reduce necessary interaction; agent work remains summarized.

Apply [data handling](data-handling.md) before verbatim preservation. Assume the message has the repository remote's visibility. Replace secrets, confidential content, and unnecessary privacy-sensitive data with typed placeholders while preserving properties needed for analysis. Operational identifiers are not redacted merely for being identifiers.

## Save and retain history

Compose and classify the message before passing it as a file to `git commit --cleanup=verbatim -F <message-file>` so shell expansion and Git's whitespace or comment cleanup do not alter transcript text. Inspect the stored message against the prepared text and user-message sequence. Keep actual trailers outside the indented transcript.

Create no new task notes and do not update, fetch, merge, or push notes refs for new task recording. Preserve existing notes and past commit messages unchanged; read historical notes when relevant. This contract does not change unrelated Git notes uses, such as release tooling.

## Runtime condition

In Codex, retrieve and compare the thread history using available means. If a dedicated tool is unavailable or cannot retrieve it, also look for an available session log; a missing tool alone does not make history unavailable. For example, use `CODEX_THREAD_ID` and `CODEX_HOME` to locate the corresponding local session log when available. Check the thread ID, successful reading and parsing, and consistency with the known cycle start, latest user message, and other known messages. If these checks pass and there are no concrete signs of missing or truncated history, treat the log as complete. If they fail, or such signs exist, seek another retrieval method; if the issue remains unresolved, do not infer missing content or save an incomplete transcript, and defer the final commit and report the capability boundary. Another runtime without an equivalent capability may explicitly skip the transcript, report that boundary, and complete the task if every other condition is satisfied.
