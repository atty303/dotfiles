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
    check(migrated.stdout.includes(external), "external block was not preserved");
    check(
      migrated.stdout.startsWith("# BEGIN chezmoi managed SSH config v2\n"),
      "missing managed block",
    );
    check(
      migrated.stdout.includes("IdentityAgent") === (os === "darwin"),
      "incorrect platform configuration",
    );
    const managedEnd = "# END chezmoi managed SSH config v2\n";
    const [managed, outside] = migrated.stdout.split(managedEnd);
    check(
      !managed.includes("Gitpod Flex") && !managed.includes("Ona CLI"),
      "integrations are managed",
    );
    check(outside.includes('Include "gitpod/config"'), "Ona integration lost");
    check(outside.includes('Include "code_gitpod_flex.d/config"'), "Gitpod integration lost");
    const changed = migrated.stdout.replace('Include "gitpod/config"', 'Include "gitpod/changed"');
    check((await render(changed, os)).stdout === changed, "integration changes were not preserved");
    const oldManagedValue = migrated.stdout.replace(
      "ServerAliveInterval 60",
      "ServerAliveInterval 99",
    );
    check(
      (await render(oldManagedValue, os)).stdout === migrated.stdout,
      "managed settings did not update",
    );
    const removed = migrated.stdout.replace('Include "gitpod/config"\n', "");
    check((await render(removed, os)).stdout === removed, "integration deletion was not preserved");
    const prior =
      `# BEGIN chezmoi managed SSH config\n${legacy.stdout}# END chezmoi managed SSH config\n${external}`;
    const upgraded = await render(
      prior.replace('Include "gitpod/config"', 'Include "gitpod/changed"'),
      os,
    );
    check(upgraded.success, upgraded.stderr);
    check(
      upgraded.stdout.split(managedEnd)[1].includes('Include "gitpod/changed"'),
      "prior managed integration lost",
    );
    check(
      (await render(upgraded.stdout, os)).stdout === upgraded.stdout,
      "upgraded config is not stable",
    );
    const withoutMarkers = prior.replace("# Ona CLI SSH Integration\n", "").replace(
      "## START Gitpod Flex VS Code INTEGRATION\n",
      "",
    );
    const upgradedWithoutMarkers = await render(withoutMarkers, os);
    check(upgradedWithoutMarkers.success, upgradedWithoutMarkers.stderr);
    const preserved = upgradedWithoutMarkers.stdout.split(managedEnd)[1];
    check(
      preserved.includes('Include "gitpod/config"') &&
        preserved.includes('Include "code_gitpod_flex.d/config"'),
      "integration content without markers was lost",
    );
    const moved = prior.replace('Include "gitpod/config"\n', "").replace(
      "# GitHub Codespaces",
      'Include "gitpod/changed"\n# GitHub Codespaces',
    );
    const movedResult = await render(moved, os);
    check(
      !movedResult.success && movedResult.stdout === "",
      "moved integration must stop migration",
    );
    const again = await render(migrated.stdout + external, os);
    check(
      again.success && again.stdout === migrated.stdout + external,
      "external changes or idempotence failed",
    );
    const fresh = await render("", os);
    check(
      fresh.success && fresh.stdout.endsWith(managedEnd),
      "new config failed",
    );
    for (
      const invalid of [
        old.replace("ServerAliveInterval 60", "ServerAliveInterval 61"),
        migrated.stdout.replace(managedEnd, ""),
      ]
    ) {
      const result = await render(invalid, os);
      check(!result.success && result.stdout === "", "ambiguous config must fail without output");
    }
  });
}
