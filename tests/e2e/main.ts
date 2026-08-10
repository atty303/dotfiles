import { Command, EnumType } from "@cliffy/command";
import { type LinuxTarget, runLinuxTargets } from "./linux.ts";
import { runMacHost, runMacLan, runMacLocal } from "./mac.ts";
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
  )
  .command(
    "lan",
    new Command().description("Run the macOS E2E on E2E_MAC_HOST over SSH").action(runMacLan),
  )
  .command(
    "host",
    new Command()
      .description("Run a staged macOS E2E on the current Mac host")
      .hidden()
      .arguments("<staging-directory:string> <recipient:string>")
      .action((_options, stagingDirectory: string, recipient: string) =>
        runMacHost(stagingDirectory, recipient)
      ),
  );

await new Command()
  .name("chezmoi-e2e")
  .version("0.1.0")
  .description("Full end-to-end tests for this chezmoi source state")
  .command("linux", linuxCommand)
  .command("mac", macCommand)
  .parse(Deno.args);
