import { join } from "node:path";

const installedValidator = new URL("./validate-reference-graph.ts", import.meta.url);
const sourceValidator = new URL("./executable_validate-reference-graph.ts", import.meta.url);
const validatorUrl = await Deno.stat(installedValidator).then(() => installedValidator).catch(() =>
  sourceValidator
);
const { validateReferenceGraph } = await import(validatorUrl.href) as {
  validateReferenceGraph: (root: string) => Promise<{ kind: string }[]>;
};

function assertKinds(actual: { kind: string }[], expected: string[]): void {
  const kinds = actual.map((issue) => issue.kind).sort();
  const wanted = [...expected].sort();
  if (JSON.stringify(kinds) !== JSON.stringify(wanted)) {
    throw new Error(`expected ${JSON.stringify(wanted)}, received ${JSON.stringify(kinds)}`);
  }
}

async function fixture(
  files: Record<string, string>,
  run: (root: string) => Promise<void>,
): Promise<void> {
  const root = await Deno.makeTempDir({ prefix: "reference-graph-test-" });
  try {
    for (const [relative, body] of Object.entries(files)) {
      const path = join(root, relative);
      await Deno.mkdir(join(path, ".."), { recursive: true });
      await Deno.writeTextFile(path, body);
    }
    await run(root);
  } finally {
    await Deno.remove(root, { recursive: true });
  }
}

Deno.test("accepts an acyclic in-workspace graph", async () => {
  await fixture({ "a.md": "[b](b.md)\n", "b.md": "ok\n" }, async (root) => {
    assertKinds(await validateReferenceGraph(root), []);
  });
});

Deno.test("rejects missing and outside targets", async () => {
  await fixture({ "a.md": "[missing](none.md)\n[out](../outside.md)\n" }, async (root) => {
    assertKinds(await validateReferenceGraph(root), ["missing", "outside"]);
  });
});

Deno.test("rejects self and multi-file cycles", async () => {
  await fixture({
    "self.md": "[self](self.md)\n",
    "a.md": "[b](b.md)\n",
    "b.md": "[a](a.md)\n",
  }, async (root) => {
    assertKinds(await validateReferenceGraph(root), ["cycle", "self-cycle"]);
  });
});

Deno.test("rejects a symlink escape", async () => {
  const parent = await Deno.makeTempDir({ prefix: "reference-graph-symlink-test-" });
  try {
    const root = join(parent, "root");
    const outside = join(parent, "outside.md");
    await Deno.mkdir(root);
    await Deno.writeTextFile(outside, "outside\n");
    await Deno.symlink(outside, join(root, "linked.md"));
    await Deno.writeTextFile(join(root, "a.md"), "[linked](linked.md)\n");
    assertKinds(await validateReferenceGraph(root), ["outside"]);
  } finally {
    await Deno.remove(parent, { recursive: true });
  }
});

Deno.test("rejects internal symlink self and multi-file cycles", async () => {
  const root = await Deno.makeTempDir({ prefix: "reference-graph-internal-symlink-test-" });
  try {
    await Deno.writeTextFile(join(root, "self.md"), "[alias](self-alias.md)\n");
    await Deno.symlink(join(root, "self.md"), join(root, "self-alias.md"));
    await Deno.writeTextFile(join(root, "a.md"), "[b alias](b-alias.md)\n");
    await Deno.writeTextFile(join(root, "b.md"), "[a](a.md)\n");
    await Deno.symlink(join(root, "b.md"), join(root, "b-alias.md"));
    assertKinds(await validateReferenceGraph(root), ["self-cycle", "cycle"]);
  } finally {
    await Deno.remove(root, { recursive: true });
  }
});
