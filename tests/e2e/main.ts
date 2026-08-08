import { Command, EnumType } from "@cliffy/command";
import { type LinuxTarget, runLinuxTargets } from "./linux.ts";

const linuxTarget = new EnumType(["fedora", "ubuntu", "all"] as const);

const linuxCommand = new Command()
  .description("Run a full chezmoi apply in clean Linux containers")
  .type("linux-target", linuxTarget)
  .arguments("<target:linux-target>")
  .action(async (_options, target: LinuxTarget | "all") => {
    await runLinuxTargets(target);
  });

await new Command()
  .name("chezmoi-e2e")
  .version("0.1.0")
  .description("Full end-to-end tests for this chezmoi source state")
  .command("linux", linuxCommand)
  .parse(Deno.args);
