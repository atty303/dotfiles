import { join } from "node:path";
import {
  collectSessionEvidence,
  type SessionEvidence,
} from "../home/dot_agents/skills/maintain-agent-guidance/scripts/executable_collect-session-evidence.ts";

const ROOT_START = "2026-08-10T00:00:00.000Z";

function assert(condition: unknown, message = "assertion failed"): asserts condition {
  if (!condition) throw new Error(message);
}

function assertFalse(condition: unknown, message = "assertion failed"): void {
  if (condition) throw new Error(message);
}

function assertEquals(actual: unknown, expected: unknown): void {
  const actualJson = JSON.stringify(actual);
  const expectedJson = JSON.stringify(expected);
  if (actualJson !== expectedJson) {
    throw new Error(`expected ${expectedJson}, received ${actualJson}`);
  }
}

function record(type: string, timestamp: string, payload: Record<string, unknown>): string {
  return JSON.stringify({ type, timestamp, payload });
}

function rootSession(
  id: string,
  options: { completed?: boolean; start?: string; assistantText?: string; userText?: string } = {},
): string {
  const start = options.start ?? ROOT_START;
  const userText = options.userText ?? [
    "fix this with ghp_abcdefghijklmnopqrstuvwxyz123456",
    "password is hunter2",
    "token=token-value-123",
    "example --password flag-secret",
    "https://alice:hunter2@example.com/path",
    `xoxb-${"1234567890"}-abcdefghijklmnop`,
    "AKIAABCDEFGHIJKLMNOP",
    "npm_abcdefghijklmnopqrstuvwxyz123456",
    "eyJheader123.eyJpayload456.signature789",
    "Bearer bearer-token-123",
    "Bearer abcdefghijklmnopqrstuvwxyz",
    "Bearer zyxwvutsrqponmlkjihgfedcba was rejected",
    "Basic YWxpY2U6aHVudGVyMg==",
    "Basic dXNlcjpwYXNz",
    "Basic dXNlcjphYmNk was rejected",
    "Cookie: session=private-cookie",
    "prefix Cookie: session=embedded-cookie",
    "Authorization: Digest username=alice, response=digest-secret",
    '{"Authorization":"Digest username=alice, response=json-auth-secret"}',
    'request={"password":"json-password","token":"json-token","Cookie":"json-cookie"}',
    '{"password":"\\"escaped-json-secret"}',
    'password = "correct horse battery staple"',
    '--password "quoted flag secret"',
    "session_cookie=session-cookie-secret",
    "AWS_SECRET_ACCESS_KEY=aws-secret-access-key",
    "GITHUB_TOKEN=github-field-token",
    "DB_PASSWORD=db-password",
    "https://example.com/login?client_secret=query-secret&x=1",
    "https://example.com/login?X-Amz-Security-Token=aws-session-secret&x=1",
    "https://example.com/file?X-Amz-Signature=private-signature",
    `-----BEGIN ${"PRIVATE"} KEY-----\nfake-private-key\n-----END ${"PRIVATE"} KEY-----`,
  ].join("\n");
  const lines = [
    record("session_meta", start, { id, cwd: "/repo", source: "vscode" }),
    record("response_item", "2026-08-10T00:00:01.000Z", {
      type: "message",
      role: "user",
      content: [
        { type: "input_text", text: "# AGENTS.md instructions for /repo\nsecret context" },
        {
          type: "input_text",
          text: userText,
        },
      ],
    }),
    record("response_item", "2026-08-10T00:00:02.000Z", {
      type: "message",
      role: "assistant",
      content: [{
        type: "output_text",
        text: options.assistantText ??
          "Using AGE-SECRET-KEY-1QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ",
      }],
    }),
    record("response_item", "2026-08-10T00:00:03.000Z", {
      type: "custom_tool_call",
      call_id: "call-1",
      name: "exec",
      status: "completed",
      input: "do-not-expose-command --password hunter2",
    }),
    record("response_item", "2026-08-10T00:00:04.000Z", {
      type: "custom_tool_call_output",
      call_id: "call-1",
      output: [{ type: "input_text", text: "Script completed\nOutput:\nraw-secret-output" }],
    }),
  ];
  if (options.completed !== false) {
    lines.push(record("event_msg", "2026-08-10T00:00:05.000Z", { type: "task_complete" }));
  }
  return `${lines.join("\n")}\n`;
}

async function writeLog(root: string, relative: string, content: string): Promise<void> {
  const path = join(root, relative);
  await Deno.mkdir(join(path, ".."), { recursive: true });
  await Deno.writeTextFile(path, content);
}

async function withCodexHome(run: (home: string) => Promise<void>): Promise<void> {
  const home = await Deno.makeTempDir({ prefix: "agent-guidance-session-test-" });
  try {
    await run(home);
  } finally {
    await Deno.remove(home, { recursive: true });
  }
}

function serialized(session: SessionEvidence): string {
  return JSON.stringify(session);
}

Deno.test("collects completed roots without tool arguments or raw outputs", async () => {
  await withCodexHome(async (home) => {
    await writeLog(home, "sessions/2026/08/10/rollout-root.jsonl", rootSession("root"));

    const result = await collectSessionEvidence({ codexHome: home });
    assertEquals(result.sessions.length, 1);
    const evidence = serialized(result.sessions[0]);
    assert(evidence.includes("[REDACTED_GITHUB_TOKEN]"));
    assert(evidence.includes("[REDACTED_AGE_SECRET_KEY]"));
    assertFalse(evidence.includes("ghp_abcdefghijklmnopqrstuvwxyz123456"));
    assertFalse(evidence.includes("do-not-expose-command"));
    assertFalse(evidence.includes("raw-secret-output"));
    assertFalse(evidence.includes("hunter2"));
    assertFalse(evidence.includes("alice:"));
    assertFalse(evidence.includes("xoxb-"));
    assertFalse(evidence.includes("private-cookie"));
    assertFalse(evidence.includes("private-signature"));
    assertFalse(evidence.includes("embedded-cookie"));
    assertFalse(evidence.includes("digest-secret"));
    assertFalse(evidence.includes("json-auth-secret"));
    assertFalse(evidence.includes("json-password"));
    assertFalse(evidence.includes("json-token"));
    assertFalse(evidence.includes("json-cookie"));
    assertFalse(evidence.includes("escaped-json-secret"));
    assertFalse(evidence.includes("correct horse battery staple"));
    assertFalse(evidence.includes("quoted flag secret"));
    assertFalse(evidence.includes("session-cookie-secret"));
    assertFalse(evidence.includes("aws-secret-access-key"));
    assertFalse(evidence.includes("github-field-token"));
    assertFalse(evidence.includes("db-password"));
    assertFalse(evidence.includes("query-secret"));
    assertFalse(evidence.includes("aws-session-secret"));
    assertFalse(evidence.includes("AKIAABCDEFGHIJKLMNOP"));
    assertFalse(evidence.includes("npm_abcdefghijklmnopqrstuvwxyz123456"));
    assertFalse(evidence.includes("eyJheader123.eyJpayload456.signature789"));
    assertFalse(evidence.includes("bearer-token-123"));
    assertFalse(evidence.includes("YWxpY2U6aHVudGVyMg=="));
    assertFalse(evidence.includes("abcdefghijklmnopqrstuvwxyz"));
    assertFalse(evidence.includes("zyxwvutsrqponmlkjihgfedcba"));
    assertFalse(evidence.includes("dXNlcjpwYXNz"));
    assertFalse(evidence.includes("dXNlcjphYmNk"));
    assertFalse(evidence.includes("fake-private-key"));
    assertFalse(evidence.includes("token-value-123"));
    assertFalse(evidence.includes("flag-secret"));
    assert(evidence.includes("password is [REDACTED]"));
    assert(evidence.includes("token=[REDACTED]"));
    assert(evidence.includes("--password [REDACTED]"));
    assert(evidence.includes("Cookie: [REDACTED]"));
    assertFalse(evidence.includes("Cookie: [REDACTED]]"));
    assertFalse(evidence.includes("AGENTS.md instructions"));
    assert(result.sessions[0].redactedMessages > 0);
    assertEquals(result.sessions[0].tools, [{
      name: "exec",
      status: "completed",
      outcome: "succeeded",
    }]);
  });
});

Deno.test("retains operational identifiers and non-secret credential discussion", async () => {
  await withCodexHome(async (home) => {
    const operational = [
      "/home/atty/src/project",
      "host=personal-workstation uid=1000 pid=4242 port=3030",
      "uuid=019c6e27-e55b-73d1-87d8-4e01f1f75043",
      "commit=75650fe822b12cf54816f263106a2e68aff59311",
      "sha256=b92bbba31b8f9c3f968afe8481f65aec411f95d4f211c19f671c67752d8d275d",
      "artifact=BuildResult2026ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnop",
      "credential policy was reviewed without exposing a value",
      "token is a lexical unit in the parser",
      "secret is a TypeScript keyword in this example",
      "Bearer token handling is documented",
      "Basic authentication policy is documented",
      "Use Bearer authentication.",
      "Use Bearer authorization.",
      "Use Basic authentication.",
      "Use Basic authorization.",
      "token: a lexical unit in the parser",
      "secret: a TypeScript keyword in this example",
      "Cookie: HTTP state is described here",
    ].join("\n");
    await writeLog(
      home,
      "sessions/rollout-operational.jsonl",
      rootSession("operational", {
        assistantText: operational,
        userText: "inspect the authorized local diagnostic output",
      }),
    );

    const result = await collectSessionEvidence({ codexHome: home });
    const evidence = serialized(result.sessions[0]);
    for (const value of operational.split("\n")) {
      assert(evidence.includes(value), `expected operational value to remain: ${value}`);
    }
    assertEquals(result.sessions[0].redactedMessages, 0);
  });
});

Deno.test("retains tail evidence and reports truncated or omitted messages", async () => {
  await withCodexHome(async (home) => {
    const longMessages = Array.from(
      { length: 20 },
      (_value, index) =>
        record("response_item", `2026-08-10T00:01:${String(index).padStart(2, "0")}.000Z`, {
          type: "message",
          role: index % 2 === 0 ? "user" : "assistant",
          content: [{
            type: index % 2 === 0 ? "input_text" : "output_text",
            text: index === 19
              ? `${"tail ".repeat(1_000)}TAIL_CORRECTION`
              : `message ${index} ${"word ".repeat(780)}`,
          }],
        }),
    );
    const session = [
      record("session_meta", ROOT_START, { id: "long", cwd: "/repo", source: "vscode" }),
      record("event_msg", ROOT_START, { type: "task_started" }),
      ...longMessages,
      record("event_msg", "2026-08-10T00:02:00.000Z", { type: "task_complete" }),
    ].join("\n");
    await writeLog(home, "sessions/rollout-long.jsonl", session);

    const result = await collectSessionEvidence({ codexHome: home });
    const evidence = result.sessions[0];
    assert(evidence.truncatedMessages > 0);
    assertEquals(evidence.redactedMessages, 0);
    assert(
      evidence.omittedMessages > 0,
      `expected omitted messages: ${
        JSON.stringify({
          count: evidence.messages.length,
          lengths: evidence.messages.map((message) => message.text.length),
          truncated: evidence.truncatedMessages,
        })
      }`,
    );
    assert(serialized(evidence).includes("message 0 "));
    assert(serialized(evidence).includes("TAIL_CORRECTION"));
  });
});

Deno.test("excludes subagents, incomplete sessions, and requested thread IDs", async () => {
  await withCodexHome(async (home) => {
    await writeLog(home, "sessions/rollout-root.jsonl", rootSession("excluded"));
    await writeLog(
      home,
      "sessions/rollout-incomplete.jsonl",
      rootSession("incomplete", { completed: false }),
    );
    const subagent = [
      record("session_meta", ROOT_START, {
        id: "subagent",
        cwd: "/repo",
        source: { subagent: { thread_spawn: { parent_thread_id: "root" } } },
      }),
      record("event_msg", "2026-08-10T00:00:05.000Z", { type: "task_complete" }),
    ].join("\n");
    await writeLog(home, "archived_sessions/rollout-subagent.jsonl", subagent);

    const result = await collectSessionEvidence({
      codexHome: home,
      excludeThreads: new Set(["excluded"]),
    });
    assertEquals(result.sessions, []);
    assertEquals(result.coverage.deduplicatedCompletedRootSessions, 1);
    assertEquals(result.coverage.eligibleSessions, 0);
  });
});

Deno.test("excludes a session whose latest turn is incomplete or aborted", async () => {
  await withCodexHome(async (home) => {
    const incompleteLatestTurn = [
      rootSession("active").trimEnd(),
      record("event_msg", "2026-08-10T00:01:00.000Z", { type: "task_started" }),
      record("response_item", "2026-08-10T00:01:01.000Z", {
        type: "message",
        role: "user",
        content: [{ type: "input_text", text: "continue" }],
      }),
    ].join("\n");
    const abortedLatestTurn = [
      rootSession("aborted").trimEnd(),
      record("event_msg", "2026-08-10T00:02:00.000Z", { type: "task_started" }),
      record("event_msg", "2026-08-10T00:02:01.000Z", { type: "turn_aborted" }),
    ].join("\n");
    await writeLog(home, "sessions/rollout-active.jsonl", incompleteLatestTurn);
    await writeLog(home, "archived_sessions/rollout-aborted.jsonl", abortedLatestTurn);

    const result = await collectSessionEvidence({ codexHome: home });
    assertEquals(result.sessions, []);
    assertEquals(result.coverage.deduplicatedCompletedRootSessions, 0);
  });
});

Deno.test("deduplicates by session ID and keeps the most complete log", async () => {
  await withCodexHome(async (home) => {
    await writeLog(
      home,
      "sessions/rollout-duplicate.jsonl",
      rootSession("duplicate", { assistantText: "older evidence" }),
    );
    const newer = rootSession("duplicate", { assistantText: "newer evidence" }).replaceAll(
      "2026-08-10T00:00:05.000Z",
      "2026-08-10T00:01:05.000Z",
    );
    await writeLog(home, "archived_sessions/rollout-duplicate.jsonl", newer);

    const result = await collectSessionEvidence({ codexHome: home });
    assertEquals(result.sessions.length, 1);
    assert(serialized(result.sessions[0]).includes("newer evidence"));
    assertFalse(serialized(result.sessions[0]).includes("older evidence"));
  });
});

Deno.test("reports malformed JSONL without treating evidence as complete", async () => {
  await withCodexHome(async (home) => {
    await writeLog(
      home,
      "sessions/rollout-malformed.jsonl",
      `${rootSession("malformed")}not-json\n`,
    );

    const result = await collectSessionEvidence({ codexHome: home });
    assertEquals(result.sessions[0].parseWarnings, 1);
    assertEquals(result.coverage.malformedLines, 1);
  });
});

Deno.test("applies the time window and oldest-first limit", async () => {
  await withCodexHome(async (home) => {
    await writeLog(
      home,
      "sessions/rollout-older.jsonl",
      rootSession("older", { start: "2026-08-08T00:00:00.000Z" }),
    );
    await writeLog(
      home,
      "sessions/rollout-first.jsonl",
      rootSession("first", { start: "2026-08-10T00:00:00.000Z" }),
    );
    await writeLog(
      home,
      "sessions/rollout-second.jsonl",
      rootSession("second", { start: "2026-08-11T00:00:00.000Z" }),
    );

    const result = await collectSessionEvidence({
      codexHome: home,
      after: new Date("2026-08-09T00:00:00.000Z"),
      before: new Date("2026-08-12T00:00:00.000Z"),
      limit: 1,
    });
    assertEquals(result.sessions.map((session) => session.sessionId), ["first"]);
    assertEquals(result.coverage.remainingSessions, 1);
  });
});
