import { Command, EnumType } from "@cliffy/command";
import { runHostE2e } from "./host.ts";
import { type LinuxTarget, runLinuxTargets } from "./linux.ts";
import { runMacLocal } from "./mac.ts";
import { prepareMacHost } from "./mac_prepare.ts";

const linuxTarget = new EnumType(
  [
    "bazzite",
    "fedora",
    "ubuntu-desktop",
    "ubuntu-headless",
  ] as const,
);

const linuxCommand = new Command()
  .description("Run a full chezmoi apply in clean Linux containers")
  .type("linux-target", linuxTarget)
  .arguments("[target:linux-target]")
  .action(async (_options, target?: LinuxTarget) => {
    await runLinuxTargets(target);
  });

const macCommand = new Command()
  .description("Run full chezmoi applies in Tart macOS VMs")
  .command(
    "prepare",
    new Command()
      .description("Pull the pinned image and validate Tart VM execution")
      .action(prepareMacHost),
  )
  .command(
    "local",
    new Command().description("Run the macOS E2E on this Apple Silicon Mac").action(runMacLocal),
  );

await new Command()
  .name("chezmoi-e2e")
  .version("0.1.0")
  .description("Full end-to-end tests for this chezmoi source state")
  .action(runHostE2e)
  .command("linux", linuxCommand)
  .command("mac", macCommand)
  .parse(Deno.args);
