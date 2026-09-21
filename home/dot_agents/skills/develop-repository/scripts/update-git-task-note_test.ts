import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const installedHelper = join(scriptDirectory, "update-git-task-note.ts");
const sourceHelper = join(scriptDirectory, "executable_update-git-task-note.ts");
const helper = await Deno.stat(installedHelper).then(() => installedHelper).catch(() =>
  sourceHelper
);
const decoder = new TextDecoder();

async function command(cwd: string, executable: string, args: string[]) {
  const result = await new Deno.Command(executable, { cwd, args, stdout: "piped", stderr: "piped" })
    .output();
  return {
    code: result.code,
    stdout: decoder.decode(result.stdout).trim(),
    stderr: decoder.decode(result.stderr).trim(),
  };
}

async function git(cwd: string, args: string[]): Promise<string> {
  const result = await command(cwd, "git", args);
  if (result.code !== 0) throw new Error(result.stderr);
  return result.stdout;
}

async function repository(run: (root: string, anchor: string) => Promise<void>): Promise<void> {
  const root = await Deno.makeTempDir({ prefix: "git-task-note-test-" });
  try {
    await git(root, ["init", "-q"]);
    await git(root, ["config", "user.name", "Test User"]);
    await git(root, ["config", "user.email", "test@example.invalid"]);
    await Deno.writeTextFile(join(root, "tracked"), "fixture\n");
    await git(root, ["add", "tracked"]);
    await git(root, ["commit", "-qm", "test fixture"]);
    await run(root, await git(root, ["rev-parse", "HEAD"]));
  } finally {
    await Deno.remove(root, { recursive: true });
  }
}

function body(anchor: string, task = "test note"): string {
  return [
    `Task: ${task}`,
    `Anchor: ${anchor}`,
    `Base: ${anchor}`,
    "Branch: main",
    `Commits: ${anchor} fixture`,
    "Guidance: develop-repository; git-task-evidence",
    "Conditions: isolated fixture",
    "Authority: current source and test",
    "## Transcript",
    "- U1: create a test note",
    "  - A: validated and wrote the normalized note",
    "",
  ].join("\n");
}

async function invoke(root: string, anchor: string, input: string, expected: string) {
  const inputPath = join(root, "note.md");
  await Deno.writeTextFile(inputPath, input);
  return await command(root, "deno", [
    "run",
    "--allow-read",
    "--allow-run=git",
    helper,
    "--anchor",
    anchor,
    "--input",
    inputPath,
    "--expected-note",
    expected,
  ]);
}

Deno.test("adds and replaces a normalized note", async () => {
  await repository(async (root, anchor) => {
    const added = await invoke(root, anchor, body(anchor), "absent");
    if (added.code !== 0) throw new Error(added.stderr);
    const firstBlob = await git(root, ["notes", "--ref=commits", "list", anchor]);
    const replaced = await invoke(root, anchor, body(anchor, "replacement"), firstBlob);
    if (replaced.code !== 0) throw new Error(replaced.stderr);
    const shown = await git(root, ["notes", "--ref=commits", "show", anchor]);
    if (!shown.startsWith("Task: replacement")) throw new Error("replacement was not stored");
  });
});

Deno.test("rejects invalid schema without writing", async () => {
  await repository(async (root, anchor) => {
    const result = await invoke(root, anchor, "not normalized\n", "absent");
    if (result.code === 0 || !result.stderr.includes("git-task-note:schema:")) {
      throw new Error(`expected schema failure, received ${JSON.stringify(result)}`);
    }
    const listed = await command(root, "git", ["notes", "--ref=commits", "list", anchor]);
    if (listed.code === 0) throw new Error("invalid note was written");
  });
});

Deno.test("rejects content after the final transcript exchange", async () => {
  await repository(async (root, anchor) => {
    const invalid = `${body(anchor)}## Extra\nnot part of an exchange\n`;
    const result = await invoke(root, anchor, invalid, "absent");
    if (result.code === 0 || !result.stderr.includes("git-task-note:schema:")) {
      throw new Error(`expected schema failure, received ${JSON.stringify(result)}`);
    }
    const listed = await command(root, "git", ["notes", "--ref=commits", "list", anchor]);
    if (listed.code === 0) throw new Error("invalid note was written");
  });
});

Deno.test("rejects user content after an A child", async () => {
  await repository(async (root, anchor) => {
    const invalid = body(anchor).replace(
      "  - A: validated and wrote the normalized note\n",
      "  - A: summary inserted too early\n    later user content\n",
    );
    const result = await invoke(root, anchor, invalid, "absent");
    if (result.code === 0 || !result.stderr.includes("git-task-note:schema:")) {
      throw new Error(`expected schema failure, received ${JSON.stringify(result)}`);
    }
  });
});

Deno.test("rejects stale expected state without overwriting", async () => {
  await repository(async (root, anchor) => {
    const initial = join(root, "initial.md");
    await Deno.writeTextFile(initial, "pre-existing note\n");
    await git(root, ["notes", "--ref=commits", "add", "-F", initial, anchor]);
    const result = await invoke(root, anchor, body(anchor), "absent");
    if (result.code === 0 || !result.stderr.includes("git-task-note:conflict:")) {
      throw new Error(`expected conflict, received ${JSON.stringify(result)}`);
    }
    const shown = await git(root, ["notes", "--ref=commits", "show", anchor]);
    if (shown !== "pre-existing note") throw new Error("existing note was overwritten");
  });
});
