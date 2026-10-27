const encoder = new TextEncoder();
const decoder = new TextDecoder();
const modifier = "home/private_dot_ssh/modify_config";

async function render(input: string, os: string, template = modifier) {
  const child = new Deno.Command("chezmoi", {
    args: [
      "execute-template",
      "--with-stdin",
      "--override-data",
      JSON.stringify({ chezmoi: { os } }),
      "--file",
      template,
    ],
    stdin: "piped",
    stdout: "piped",
    stderr: "piped",
  }).spawn();
  const writer = child.stdin.getWriter();
  await writer.write(encoder.encode(input));
  await writer.close();
  const result = await child.output();
  return {
    success: result.success,
    stdout: decoder.decode(result.stdout),
    stderr: decoder.decode(result.stderr),
  };
}

function check(condition: boolean, message: string): asserts condition {
  if (!condition) throw new Error(message);
}

for (const os of ["darwin", "linux", "windows"]) {
  Deno.test(`SSH config migration and external changes on ${os}`, async () => {
    const legacy = await render("", os, "home/.chezmoitemplates/ssh-config-legacy");
    check(legacy.success, legacy.stderr);
    const external = "# external\nHost external.example\n  User external\n";
    const old = legacy.stdout.replace(
      "# If the SSH agent is not forwarded",
      `${external}# If the SSH agent is not forwarded`,
    );
    const migrated = await render(old, os);
    check(migrated.success, migrated.stderr);
    check(migrated.stdout.endsWith(external), "external block was not preserved");
    check(
      migrated.stdout.startsWith("# BEGIN chezmoi managed SSH config\n"),
      "missing managed block",
    );
    check(
      migrated.stdout.includes("IdentityAgent") === (os === "darwin"),
      "incorrect platform configuration",
    );
    const again = await render(migrated.stdout + external, os);
    check(
      again.success && again.stdout === migrated.stdout + external,
      "external changes or idempotence failed",
    );
    const fresh = await render("", os);
    check(
      fresh.success && fresh.stdout.endsWith("# END chezmoi managed SSH config\n"),
      "new config failed",
    );
    for (
      const invalid of [
        old.replace("ServerAliveInterval 60", "ServerAliveInterval 61"),
        migrated.stdout.replace("# END chezmoi managed SSH config\n", ""),
      ]
    ) {
      const result = await render(invalid, os);
      check(!result.success && result.stdout === "", "ambiguous config must fail without output");
    }
  });
}
