#!/usr/bin/env -S deno run --allow-read --allow-run=git

type Options = {
  anchor: string;
  input: string;
  expectedNote: string;
};

class NoteError extends Error {
  constructor(readonly code: string, message: string) {
    super(message);
  }
}

const decoder = new TextDecoder();

async function git(args: string[]): Promise<{ code: number; stdout: string; stderr: string }> {
  const result = await new Deno.Command("git", {
    args,
    stdout: "piped",
    stderr: "piped",
  }).output();
  return {
    code: result.code,
    stdout: decoder.decode(result.stdout).trim(),
    stderr: decoder.decode(result.stderr).trim(),
  };
}

async function gitOk(args: string[], code: string): Promise<string> {
  const result = await git(args);
  if (result.code !== 0) {
    throw new NoteError(code, result.stderr || `git ${args[0]} failed`);
  }
  return result.stdout;
}

function parseArgs(args: string[]): Options {
  const values = new Map<string, string>();
  for (let index = 0; index < args.length; index += 2) {
    const key = args[index];
    const value = args[index + 1];
    if (!key?.startsWith("--") || value === undefined) {
      throw new NoteError(
        "usage",
        "expected --anchor SHA --input FILE --expected-note BLOB|absent",
      );
    }
    if (values.has(key)) throw new NoteError("usage", `duplicate option ${key}`);
    values.set(key, value);
  }
  const anchor = values.get("--anchor");
  const input = values.get("--input");
  const expectedNote = values.get("--expected-note");
  if (values.size !== 3 || !anchor || !input || !expectedNote) {
    throw new NoteError("usage", "expected --anchor SHA --input FILE --expected-note BLOB|absent");
  }
  if (expectedNote !== "absent" && !/^[0-9a-f]{40}([0-9a-f]{24})?$/.test(expectedNote)) {
    throw new NoteError("usage", "--expected-note must be a Git object ID or absent");
  }
  return { anchor, input, expectedNote };
}

function validateBody(body: string, anchor: string): void {
  if (body.includes("\0")) throw new NoteError("schema", "note contains NUL");
  if (!body.endsWith("\n")) throw new NoteError("schema", "note must end with a newline");
  const lines = body.slice(0, -1).split("\n");
  const fields = ["Task", "Anchor", "Base", "Branch", "Commits", "Guidance", "Conditions"];
  for (let index = 0; index < fields.length; index++) {
    const prefix = `${fields[index]}: `;
    if (!lines[index]?.startsWith(prefix) || lines[index] === prefix) {
      throw new NoteError("schema", `missing or empty ${fields[index]} metadata`);
    }
  }
  if (lines[1] !== `Anchor: ${anchor}`) {
    throw new NoteError("schema", "Anchor metadata does not match resolved anchor");
  }

  const transcriptIndex = lines.indexOf("## Transcript");
  if (
    transcriptIndex < fields.length + 1 || transcriptIndex !== lines.lastIndexOf("## Transcript")
  ) {
    throw new NoteError("schema", "Transcript must be the final unique section");
  }
  const authorityIndex = transcriptIndex - 1;
  if (
    !lines[authorityIndex]?.startsWith("Authority: ") || lines[authorityIndex] === "Authority: "
  ) {
    throw new NoteError("schema", "Authority must immediately precede Transcript");
  }
  const middle = lines.slice(fields.length, authorityIndex);
  if (middle.length > 0) {
    if (
      middle[0] !== "## Evidence" || middle.length === 1 ||
      middle.some((line, index) => index > 0 && line.startsWith("## "))
    ) {
      throw new NoteError("schema", "only a non-empty Evidence section may precede Authority");
    }
  }

  const transcript = lines.slice(transcriptIndex + 1);
  const userIndexes: number[] = [];
  for (let index = 0; index < transcript.length; index++) {
    if (/^- U\d+:/.test(transcript[index])) userIndexes.push(index);
  }
  if (userIndexes.length === 0 || userIndexes[0] !== 0) {
    throw new NoteError("schema", "Transcript must begin with U1");
  }
  for (let exchange = 0; exchange < userIndexes.length; exchange++) {
    const start = userIndexes[exchange];
    const end = userIndexes[exchange + 1] ?? transcript.length;
    const expected = exchange + 1;
    if (!transcript[start].startsWith(`- U${expected}:`)) {
      throw new NoteError("schema", "user exchanges must be consecutive from U1");
    }
    const exchangeLines = transcript.slice(start + 1, end);
    const agentIndexes = exchangeLines.flatMap((line, index) =>
      line.startsWith("  - A:") ? [index] : []
    );
    if (
      agentIndexes.length !== 1 || agentIndexes[0] !== exchangeLines.length - 1 ||
      !/^  - A: \S/.test(exchangeLines[agentIndexes[0]])
    ) {
      throw new NoteError("schema", `U${expected} must have one non-empty A child`);
    }
    if (exchangeLines.slice(0, -1).some((line) => !line.startsWith("    "))) {
      throw new NoteError("schema", `U${expected} contains an invalid transcript line`);
    }
  }
}

async function noteBlob(anchor: string): Promise<string | undefined> {
  const result = await git(["notes", "--ref=commits", "list", anchor]);
  if (
    result.code === 1 &&
    /^error: no note found for object [0-9a-f]{40}([0-9a-f]{24})?\.$/.test(result.stderr)
  ) return undefined;
  if (result.code !== 0) throw new NoteError("read", result.stderr || "cannot read existing note");
  const blob = result.stdout.split(/\s+/)[0];
  if (!/^[0-9a-f]{40}([0-9a-f]{24})?$/.test(blob)) {
    throw new NoteError("read", "Git returned an invalid note object ID");
  }
  return blob;
}

async function main(): Promise<void> {
  const options = parseArgs(Deno.args);
  await gitOk(["rev-parse", "--git-dir"], "repository");
  const anchor = await gitOk(["rev-parse", "--verify", `${options.anchor}^{commit}`], "anchor");
  const body = await Deno.readTextFile(options.input).catch((error) => {
    throw new NoteError("input", error instanceof Error ? error.message : "cannot read input");
  });
  validateBody(body, anchor);

  const initialBlob = await noteBlob(anchor);
  const expected = options.expectedNote === "absent" ? undefined : options.expectedNote;
  if (initialBlob !== expected) {
    throw new NoteError("conflict", "existing note does not match --expected-note");
  }

  const notesRef = "refs/notes/commits";
  const oldRefResult = await git(["rev-parse", "--verify", notesRef]);
  const oldRef = oldRefResult.code === 0 ? oldRefResult.stdout : undefined;
  const objectFormat = await gitOk(["rev-parse", "--show-object-format"], "repository");
  const zero = "0".repeat(objectFormat === "sha256" ? 64 : 40);
  const temporaryRef = `refs/notes/codex-task-note/${crypto.randomUUID()}`;

  try {
    if (oldRef) await gitOk(["update-ref", temporaryRef, oldRef, zero], "temporary-ref");
    await gitOk([
      "notes",
      `--ref=${temporaryRef}`,
      "add",
      ...(initialBlob ? ["-f"] : []),
      "--no-stripspace",
      "-F",
      options.input,
      anchor,
    ], "write");
    const newRef = await gitOk(["rev-parse", "--verify", temporaryRef], "temporary-ref");

    const beforeSwapBlob = await noteBlob(anchor);
    if (beforeSwapBlob !== initialBlob) {
      throw new NoteError("conflict", "note changed after read and before update");
    }
    const swap = await git(["update-ref", notesRef, newRef, oldRef ?? zero]);
    if (swap.code !== 0) {
      throw new NoteError("conflict", "notes ref changed before compare-and-swap update");
    }
  } finally {
    await git(["update-ref", "-d", temporaryRef]);
  }

  const written = await noteBlob(anchor);
  if (!written) throw new NoteError("verify", "updated note cannot be read back");
  console.log(`updated refs/notes/commits for ${anchor}`);
}

if (import.meta.main) {
  try {
    await main();
  } catch (error) {
    const known = error instanceof NoteError
      ? error
      : new NoteError("unexpected", error instanceof Error ? error.message : String(error));
    console.error(`git-task-note:${known.code}: ${known.message}`);
    Deno.exit(1);
  }
}
