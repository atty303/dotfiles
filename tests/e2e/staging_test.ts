import { strict as assert } from "node:assert";
import { join } from "node:path";
import { stageRepository } from "./staging.ts";

Deno.test("staging excludes secrets and creates a decryptable fixture", async () => {
  const fixture = await Deno.makeTempDir({ prefix: "chezmoi-e2e-staging-fixture-" });
  let stagedTemp: string | undefined;

  try {
    await Deno.mkdir(join(fixture, ".git"));
    await Deno.mkdir(join(fixture, "nested"));
    await Deno.writeTextFile(join(fixture, "kept.txt"), "kept\n");
    await Deno.writeTextFile(join(fixture, ".git", "config"), "ignored\n");
    await Deno.writeTextFile(join(fixture, "key.txt.age"), "private identity\n");
    await Deno.writeTextFile(join(fixture, "nested", "secret.age"), "encrypted secret\n");

    const staged = await stageRepository(fixture, new AbortController().signal);
    stagedTemp = staged.tempDir;
    const extracted = join(fixture, "extracted");
    await Deno.mkdir(extracted);
    await run("tar", ["-xf", staged.archivePath, "-C", extracted]);

    assert.equal(await Deno.readTextFile(join(extracted, "kept.txt")), "kept\n");
    await assertMissing(join(extracted, ".git"));
    await assertMissing(join(extracted, "key.txt.age"));
    await assertMissing(join(extracted, "nested", "secret.age"));

    const identityMode = (await Deno.stat(staged.identityPath)).mode;
    assert.notEqual(identityMode, null);
    assert.equal(identityMode! & 0o777, 0o600);

    const encryptedSentinel = join(
      extracted,
      "home",
      "dot_config",
      "chezmoi-e2e",
      "encrypted_private_sentinel.txt.age",
    );
    const decrypted = await output("age", [
      "--decrypt",
      "--identity",
      staged.identityPath,
      encryptedSentinel,
    ]);
    assert.equal(decrypted, "chezmoi-e2e-sentinel\n");

    const digest = await crypto.subtle.digest("SHA-256", await Deno.readFile(staged.archivePath));
    const sha256 = Array.from(
      new Uint8Array(digest),
      (byte) => byte.toString(16).padStart(2, "0"),
    ).join("");
    assert.equal(staged.sha256, sha256);
  } finally {
    if (stagedTemp !== undefined) {
      await Deno.remove(stagedTemp, { recursive: true }).catch(() => undefined);
    }
    await Deno.remove(fixture, { recursive: true }).catch(() => undefined);
  }
});

async function assertMissing(path: string): Promise<void> {
  await assert.rejects(Deno.stat(path), Deno.errors.NotFound);
}

async function run(command: string, args: string[]): Promise<void> {
  const output = await new Deno.Command(command, { args }).output();
  if (!output.success) throw new Error(`${command} failed with exit code ${output.code}`);
}

async function output(command: string, args: string[]): Promise<string> {
  const result = await new Deno.Command(command, { args }).output();
  if (!result.success) throw new Error(`${command} failed with exit code ${result.code}`);
  return new TextDecoder().decode(result.stdout);
}
