#!/usr/bin/env -S deno run --allow-env=CODEX_HOME,HOME,USERPROFILE --allow-read

import { join } from "node:path";

const DEFAULT_LIMIT = 25;
const MAX_MESSAGE_LENGTH = 4_000;
const MAX_SESSION_TEXT = 48_000;

type Role = "user" | "assistant";
type ToolOutcome = "succeeded" | "failed" | "unknown";

interface MessageEvidence {
  timestamp: string;
  role: Role;
  text: string;
}

interface SanitizedMessage {
  text: string;
  truncated: boolean;
  redacted: boolean;
}

interface ToolEvidence {
  name: string;
  status: string;
  outcome: ToolOutcome;
}

export interface SessionEvidence {
  type: "session";
  sessionId: string;
  startedAt: string;
  completedAt: string;
  cwd: string;
  source: string;
  messages: MessageEvidence[];
  tools: ToolEvidence[];
  parseWarnings: number;
  redactedMessages: number;
  truncatedMessages: number;
  omittedMessages: number;
}

export interface CoverageEvidence {
  type: "coverage";
  after: string | null;
  before: string | null;
  discoveredFiles: number;
  deduplicatedCompletedRootSessions: number;
  eligibleSessions: number;
  selectedSessions: number;
  remainingSessions: number;
  malformedLines: number;
}

export interface CollectOptions {
  codexHome: string;
  after?: Date;
  before?: Date;
  limit?: number;
  excludeThreads?: Set<string>;
}

export interface CollectionResult {
  coverage: CoverageEvidence;
  sessions: SessionEvidence[];
}

interface ParsedSession extends SessionEvidence {
  lastTimestamp: string;
  entryCount: number;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function asRecord(value: unknown): Record<string, unknown> {
  return isRecord(value) ? value : {};
}

function redactSecrets(text: string): { text: string; redacted: boolean } {
  const redacted = text
    .replace(
      /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/g,
      "[REDACTED_PRIVATE_KEY]",
    )
    .replace(/AGE-SECRET-KEY-[A-Z0-9-]+/g, "[REDACTED_AGE_SECRET_KEY]")
    .replace(/\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/g, "[REDACTED_AWS_ACCESS_KEY]")
    .replace(/\bgh[pousr]_[A-Za-z0-9_]{20,}\b/g, "[REDACTED_GITHUB_TOKEN]")
    .replace(/\bsk-[A-Za-z0-9_-]{20,}\b/g, "[REDACTED_API_KEY]")
    .replace(/\bxox[baprs]-[A-Za-z0-9-]{10,}\b/g, "[REDACTED_SLACK_TOKEN]")
    .replace(/\bglpat-[A-Za-z0-9_-]{20,}\b/g, "[REDACTED_GITLAB_TOKEN]")
    .replace(/\bnpm_[A-Za-z0-9]{20,}\b/g, "[REDACTED_NPM_TOKEN]")
    .replace(/\bAIza[A-Za-z0-9_-]{20,}\b/g, "[REDACTED_GOOGLE_API_KEY]")
    .replace(/\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b/g, "[REDACTED_JWT]")
    .replace(/\bBearer\s+[A-Za-z0-9._~+\/-]+=*/gi, "Bearer [REDACTED]")
    .replace(/\bBasic\s+[A-Za-z0-9+/]+=*/gi, "Basic [REDACTED]")
    .replace(/(https?:\/\/)[^/\s:@]+:[^@\s/]+@/gi, "$1[REDACTED]@")
    .replace(
      /(^|\n)(\s*[A-Za-z0-9_.-]*(?:api[_-]?key|access[_-]?key|client[_-]?secret|private[_-]?key|password|refresh[_-]?token|secret|token)\s*[:=]\s*)([^\s#]+)/gi,
      "$1$2[REDACTED]",
    )
    .replace(
      /\b[A-Za-z0-9_-]{48,}\b/g,
      (value) =>
        /[A-Za-z]/.test(value) && /\d/.test(value) ? "[REDACTED_HIGH_ENTROPY_VALUE]" : value,
    )
    .replace(
      /^.*\b(?:password|passphrase|client secret|private key|api key|access key|refresh token|credential)\b.*$/gim,
      "[REDACTED_CREDENTIAL_CONTEXT]",
    );
  return { text: redacted, redacted: redacted !== text };
}

function isInjectedContext(text: string): boolean {
  const trimmed = text.trimStart();
  return [
    "# AGENTS.md instructions",
    "<environment_context>",
    "<recommended_plugins>",
    "<skill>",
  ].some((prefix) => trimmed.startsWith(prefix));
}

function sanitizeMessage(text: string): SanitizedMessage | null {
  if (isInjectedContext(text)) return null;
  const redaction = redactSecrets(text);
  const sanitized = redaction.text.trim();
  if (!sanitized) return null;
  if (sanitized.length <= MAX_MESSAGE_LENGTH) {
    return { text: sanitized, truncated: false, redacted: redaction.redacted };
  }
  const marker = "\n[TRUNCATED_MIDDLE]\n";
  const sideLength = Math.floor((MAX_MESSAGE_LENGTH - marker.length) / 2);
  return {
    text: `${sanitized.slice(0, sideLength)}${marker}${sanitized.slice(-sideLength)}`,
    truncated: true,
    redacted: redaction.redacted,
  };
}

function limitSessionMessages(
  messages: MessageEvidence[],
): { messages: MessageEvidence[]; omittedMessages: number } {
  const totalLength = messages.reduce((total, message) => total + message.text.length, 0);
  if (totalLength <= MAX_SESSION_TEXT) return { messages, omittedMessages: 0 };

  const halfBudget = Math.floor(MAX_SESSION_TEXT / 2);
  const selectedIndexes = new Set<number>();
  let headLength = 0;
  for (let index = 0; index < messages.length; index++) {
    const length = messages[index].text.length;
    if (headLength + length > halfBudget) break;
    selectedIndexes.add(index);
    headLength += length;
  }

  let tailLength = 0;
  for (let index = messages.length - 1; index >= 0; index--) {
    if (selectedIndexes.has(index)) break;
    const length = messages[index].text.length;
    if (tailLength + length > halfBudget) break;
    selectedIndexes.add(index);
    tailLength += length;
  }

  const bounded = messages.filter((_message, index) => selectedIndexes.has(index));
  return { messages: bounded, omittedMessages: messages.length - bounded.length };
}

function inferToolOutcome(value: unknown): ToolOutcome {
  let succeeded = false;
  let failed = false;

  const visit = (item: unknown): void => {
    if (Array.isArray(item)) {
      item.forEach(visit);
      return;
    }
    if (isRecord(item)) {
      if (item.isError === true) failed = true;
      if (typeof item.exit_code === "number") {
        if (item.exit_code === 0) succeeded = true;
        else failed = true;
      }
      Object.values(item).forEach(visit);
      return;
    }
    if (typeof item !== "string") return;
    if (/^(?:Script|Command) completed\b/m.test(item)) succeeded = true;
    if (
      /^(?:Script|Command) failed\b/m.test(item) ||
      /exit(?:ed)? (?:status|code) [1-9]\d*/i.test(item)
    ) {
      failed = true;
    }
  };

  visit(value);
  if (failed) return "failed";
  if (succeeded) return "succeeded";
  return "unknown";
}

async function listJsonlFiles(directory: string): Promise<string[]> {
  const files: string[] = [];
  const walk = async (path: string): Promise<void> => {
    try {
      for await (const entry of Deno.readDir(path)) {
        const child = join(path, entry.name);
        if (entry.isDirectory) await walk(child);
        else if (
          entry.isFile && entry.name.startsWith("rollout-") && entry.name.endsWith(".jsonl")
        ) {
          files.push(child);
        }
      }
    } catch (error) {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
    }
  };
  await walk(directory);
  return files.sort();
}

async function parseSession(path: string): Promise<ParsedSession | null> {
  const text = await Deno.readTextFile(path);
  const entries: Record<string, unknown>[] = [];
  let parseWarnings = 0;

  for (const line of text.split(/\r?\n/)) {
    if (!line.trim()) continue;
    try {
      const parsed: unknown = JSON.parse(line);
      if (isRecord(parsed)) entries.push(parsed);
      else parseWarnings++;
    } catch {
      parseWarnings++;
    }
  }

  const metaEntry = entries.find((entry) => {
    if (entry.type !== "session_meta") return false;
    const source = asRecord(entry.payload).source;
    return typeof source === "string";
  });
  if (!metaEntry) return null;

  const meta = asRecord(metaEntry.payload);
  const sessionId = typeof meta.id === "string" ? meta.id : "";
  const startedAt = typeof metaEntry.timestamp === "string" ? metaEntry.timestamp : "";
  if (!sessionId || !startedAt) return null;

  let lastTaskStartedIndex = -1;
  let lastTaskCompleteIndex = -1;
  let lastTurnAbortedIndex = -1;
  for (const [index, entry] of entries.entries()) {
    if (entry.type !== "event_msg") continue;
    const eventType = asRecord(entry.payload).type;
    if (eventType === "task_started") lastTaskStartedIndex = index;
    else if (eventType === "task_complete") lastTaskCompleteIndex = index;
    else if (eventType === "turn_aborted") lastTurnAbortedIndex = index;
  }
  if (
    lastTaskCompleteIndex < 0 || lastTaskCompleteIndex < lastTaskStartedIndex ||
    lastTaskCompleteIndex < lastTurnAbortedIndex
  ) return null;
  const completion = entries[lastTaskCompleteIndex];
  if (!completion || typeof completion.timestamp !== "string") return null;

  const messages: MessageEvidence[] = [];
  let redactedMessages = 0;
  let truncatedMessages = 0;
  const toolCalls = new Map<string, ToolEvidence>();

  for (const entry of entries) {
    const payload = asRecord(entry.payload);
    if (entry.type !== "response_item") continue;

    if (payload.type === "message" && (payload.role === "user" || payload.role === "assistant")) {
      const role = payload.role as Role;
      const content = Array.isArray(payload.content) ? payload.content : [];
      for (const item of content) {
        const part = asRecord(item);
        const raw = typeof part.text === "string" ? part.text : null;
        if (!raw || (part.type !== "input_text" && part.type !== "output_text")) continue;
        const sanitized = sanitizeMessage(raw);
        if (!sanitized) continue;
        if (sanitized.redacted) redactedMessages++;
        if (sanitized.truncated) truncatedMessages++;
        messages.push({
          timestamp: typeof entry.timestamp === "string" ? entry.timestamp : startedAt,
          role,
          text: sanitized.text,
        });
      }
      continue;
    }

    if (payload.type === "custom_tool_call" || payload.type === "function_call") {
      const callId = typeof payload.call_id === "string"
        ? payload.call_id
        : typeof payload.id === "string"
        ? payload.id
        : "";
      if (!callId) continue;
      toolCalls.set(callId, {
        name: typeof payload.name === "string" ? payload.name : "unknown",
        status: typeof payload.status === "string" ? payload.status : "unknown",
        outcome: "unknown",
      });
      continue;
    }

    if (payload.type === "custom_tool_call_output" || payload.type === "function_call_output") {
      const callId = typeof payload.call_id === "string" ? payload.call_id : "";
      const call = toolCalls.get(callId);
      if (call) call.outcome = inferToolOutcome(payload.output);
    }
  }

  const timestamps = entries
    .map((entry) => entry.timestamp)
    .filter((value): value is string => typeof value === "string");

  const boundedMessages = limitSessionMessages(messages);
  return {
    type: "session",
    sessionId,
    startedAt,
    completedAt: completion.timestamp,
    cwd: typeof meta.cwd === "string" ? meta.cwd : "",
    source: typeof meta.source === "string" ? meta.source : "",
    messages: boundedMessages.messages,
    tools: [...toolCalls.values()],
    parseWarnings,
    redactedMessages,
    truncatedMessages,
    omittedMessages: boundedMessages.omittedMessages,
    lastTimestamp: timestamps.at(-1) ?? completion.timestamp,
    entryCount: entries.length,
  };
}

function preferSession(current: ParsedSession, candidate: ParsedSession): ParsedSession {
  const currentTime = Date.parse(current.lastTimestamp);
  const candidateTime = Date.parse(candidate.lastTimestamp);
  if (candidateTime !== currentTime) return candidateTime > currentTime ? candidate : current;
  return candidate.entryCount > current.entryCount ? candidate : current;
}

export async function collectSessionEvidence(options: CollectOptions): Promise<CollectionResult> {
  const limit = options.limit ?? DEFAULT_LIMIT;
  if (!Number.isSafeInteger(limit) || limit < 1) {
    throw new Error("limit must be a positive integer");
  }

  const directories = [
    join(options.codexHome, "sessions"),
    join(options.codexHome, "archived_sessions"),
  ];
  const files = (await Promise.all(directories.map(listJsonlFiles))).flat();
  const sessionsById = new Map<string, ParsedSession>();
  let malformedLines = 0;

  for (const file of files) {
    const parsed = await parseSession(file);
    if (!parsed) continue;
    malformedLines += parsed.parseWarnings;
    const current = sessionsById.get(parsed.sessionId);
    sessionsById.set(parsed.sessionId, current ? preferSession(current, parsed) : parsed);
  }

  const excludeThreads = options.excludeThreads ?? new Set<string>();
  const deduplicatedCompletedRootSessions = sessionsById.size;
  const eligible = [...sessionsById.values()]
    .filter((session) => !excludeThreads.has(session.sessionId))
    .filter((session) => {
      const started = new Date(session.startedAt);
      if (Number.isNaN(started.getTime())) return false;
      if (options.after && started <= options.after) return false;
      if (options.before && started > options.before) return false;
      return true;
    })
    .sort((left, right) => left.startedAt.localeCompare(right.startedAt));

  const selected = eligible.slice(0, limit).map((
    { lastTimestamp: _last, entryCount: _count, ...session },
  ) => session);
  return {
    coverage: {
      type: "coverage",
      after: options.after?.toISOString() ?? null,
      before: options.before?.toISOString() ?? null,
      discoveredFiles: files.length,
      deduplicatedCompletedRootSessions,
      eligibleSessions: eligible.length,
      selectedSessions: selected.length,
      remainingSessions: Math.max(0, eligible.length - selected.length),
      malformedLines,
    },
    sessions: selected,
  };
}

function parseDate(value: string, flag: string): Date {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) throw new Error(`${flag} requires an RFC 3339 timestamp`);
  return date;
}

function defaultCodexHome(): string {
  const configured = Deno.env.get("CODEX_HOME");
  if (configured) return configured;
  const home = Deno.env.get("HOME") ?? Deno.env.get("USERPROFILE");
  if (!home) throw new Error("CODEX_HOME, HOME, or USERPROFILE is required");
  return join(home, ".codex");
}

async function main(args: string[]): Promise<void> {
  let after: Date | undefined;
  let before: Date | undefined;
  let limit = DEFAULT_LIMIT;
  const excludeThreads = new Set<string>();

  for (let index = 0; index < args.length; index++) {
    const flag = args[index];
    const value = args[index + 1];
    if (["--after", "--before", "--limit", "--exclude-thread"].includes(flag) && !value) {
      throw new Error(`${flag} requires a value`);
    }
    if (flag === "--after") {
      after = parseDate(value, flag);
      index++;
    } else if (flag === "--before") {
      before = parseDate(value, flag);
      index++;
    } else if (flag === "--limit") {
      limit = Number(value);
      index++;
    } else if (flag === "--exclude-thread") {
      excludeThreads.add(value);
      index++;
    } else {
      throw new Error(`unknown argument: ${flag}`);
    }
  }

  const result = await collectSessionEvidence({
    codexHome: defaultCodexHome(),
    after,
    before,
    limit,
    excludeThreads,
  });
  console.log(JSON.stringify(result.coverage));
  for (const session of result.sessions) console.log(JSON.stringify(session));
}

if (import.meta.main) {
  try {
    await main(Deno.args);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    Deno.exit(2);
  }
}
