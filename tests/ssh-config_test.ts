const encoder = new TextEncoder();
const decoder = new TextDecoder();

async function render(input: string, os: string) {
  const child = new Deno.Command("chezmoi", {
    args: [
      "execute-template",
      "--with-stdin",
      "--override-data",
      JSON.stringify({ chezmoi: { os } }),
      "--file",
      "home/private_dot_ssh/modify_config",
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
  Deno.test(`SSH config management on ${os}`, async () => {
    const fresh = await render("", os);
    check(fresh.success, fresh.stderr);
    const end = "# END chezmoi managed SSH config v2\n";
    check(fresh.stdout.endsWith(end), "new config has no managed block");
    check(
      fresh.stdout.includes("IdentityAgent") === (os === "darwin"),
      "incorrect platform configuration",
    );
    const external =
      '# Devsy Start\nHost external.example\n  User external\n# Devsy End\nInclude "gitpod/config"\nInclude "code_gitpod_flex.d/config"\n';
    const input = fresh.stdout + external;
    const unchanged = await render(input, os);
    check(
      unchanged.success && unchanged.stdout === input,
      "external settings or idempotence failed",
    );
    const changed = input.replace('Include "gitpod/config"', 'Include "gitpod/changed"');
    check((await render(changed, os)).stdout === changed, "integration changes were not preserved");
    const removed = input.replace('Include "gitpod/config"\n', "");
    check((await render(removed, os)).stdout === removed, "integration deletion was not preserved");
    const managedChange = input.replace("ServerAliveInterval 60", "ServerAliveInterval 99");
    check((await render(managedChange, os)).stdout === input, "managed settings did not update");
    for (const invalid of ["Host unknown\n", input.replace(end, ""), input + end]) {
      const result = await render(invalid, os);
      check(!result.success && result.stdout === "", "ambiguous config must fail without output");
    }
  });
}
