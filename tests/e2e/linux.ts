import { CommandBuilder } from "@david/dax";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import {
  cleanupSuccessfulResources,
  type ResourcePresence,
  retainedResourceReport,
} from "./linux_cleanup.ts";
import { type StagedSource, stageSource } from "./staging.ts";

export type LinuxTarget = "bazzite" | "fedora" | "ubuntu-desktop" | "ubuntu-headless";

interface Capabilities {
  distrobox: boolean;
  flatpak: boolean;
  xdgDesktop: boolean;
}

interface TargetConfig {
  capabilities: Capabilities;
  containerfile: string;
  home: string;
  image: string;
  label: string;
  osId: string;
  privilegedSystemd: boolean;
  target?: string;
  user: string;
  versionId: string;
}

const TARGETS: Record<LinuxTarget, TargetConfig> = {
  bazzite: {
    capabilities: { distrobox: true, flatpak: true, xdgDesktop: true },
    containerfile: "containers/bazzite-44.Containerfile",
    home: "/home/e2e",
    image: "localhost/chezmoi-e2e-bazzite:44",
    label: "Bazzite 44 desktop",
    osId: "bazzite",
    privilegedSystemd: true,
    user: "e2e",
    versionId: "44",
  },
  fedora: {
    capabilities: { distrobox: false, flatpak: false, xdgDesktop: true },
    containerfile: "containers/fedora-44.Containerfile",
    home: "/home/e2e",
    image: "localhost/chezmoi-e2e-fedora:44",
    label: "Fedora 44 compatibility",
    osId: "fedora",
    privilegedSystemd: false,
    user: "e2e",
    versionId: "44",
  },
  "ubuntu-desktop": {
    capabilities: { distrobox: false, flatpak: false, xdgDesktop: true },
    containerfile: "containers/ubuntu-24.04.Containerfile",
    home: "/home/vscode",
    image: "localhost/chezmoi-e2e-ubuntu-desktop:24.04",
    label: "Ubuntu 24.04 devcontainer desktop",
    osId: "ubuntu",
    privilegedSystemd: false,
    target: "desktop",
    user: "vscode",
    versionId: "24.04",
  },
  "ubuntu-headless": {
    capabilities: { distrobox: false, flatpak: false, xdgDesktop: false },
    containerfile: "containers/ubuntu-24.04.Containerfile",
    home: "/home/vscode",
    image: "localhost/chezmoi-e2e-ubuntu-headless:24.04",
    label: "Ubuntu 24.04 devcontainer headless",
    osId: "ubuntu",
    privilegedSystemd: false,
    target: "headless",
    user: "vscode",
    versionId: "24.04",
  },
};

export const STANDARD_LINUX_TARGETS: readonly LinuxTarget[] = [
  "fedora",
  "ubuntu-desktop",
  "ubuntu-headless",
];
const moduleDirectory = dirname(fileURLToPath(import.meta.url));
const repository = join(moduleDirectory, "..", "..");
const signalShieldedExec = 'trap "" HUP INT TERM; exec "$@"';
const cleanupTimeoutSeconds = 120;
const presenceTimeoutSeconds = 15;

export async function runLinuxTargets(target?: LinuxTarget): Promise<void> {
  const targets = selectLinuxTargets(target);
  const abort = new AbortController();
  let receivedSignal: Deno.Signal | undefined;
  let successfulCleanupStarted = false;
  const handleSignal = (signal: Deno.Signal) => {
    receivedSignal ??= signal;
    if (successfulCleanupStarted) return;
    abort.abort(new Error(`received ${signal}`));
  };
  const onInterrupt = () => handleSignal("SIGINT");
  const onTerminate = () => handleSignal("SIGTERM");

  Deno.addSignalListener("SIGINT", onInterrupt);
  Deno.addSignalListener("SIGTERM", onTerminate);

  let staged: StagedSource | undefined;
  const runId = `${new Date().toISOString().replaceAll(/[-:.TZ]/g, "")}-${
    crypto.randomUUID().slice(0, 8)
  }`;
  const failures: Array<{ target: LinuxTarget; error: unknown }> = [];

  try {
    staged = await stageSource(abort.signal);
    console.log(`source archive sha256: ${staged.sha256}`);

    for (const currentTarget of targets) {
      successfulCleanupStarted = false;
      try {
        await runLinuxTarget(
          currentTarget,
          staged,
          runId,
          abort.signal,
          () => successfulCleanupStarted = true,
        );
        if (receivedSignal !== undefined) throw new InterruptedError(receivedSignal);
      } catch (error) {
        if (receivedSignal !== undefined) {
          throw new InterruptedError(receivedSignal, { cause: error });
        }
        failures.push({ target: currentTarget, error });
        console.error(`${TARGETS[currentTarget].label} failed:`, error);
      } finally {
        successfulCleanupStarted = false;
      }
    }
  } finally {
    if (staged !== undefined) {
      await Deno.remove(staged.tempDir, { recursive: true }).catch(() => undefined);
    }
    Deno.removeSignalListener("SIGINT", onInterrupt);
    Deno.removeSignalListener("SIGTERM", onTerminate);
  }

  if (receivedSignal !== undefined) throw new InterruptedError(receivedSignal);

  if (failures.length > 0) {
    const names = failures.map(({ target }) => TARGETS[target].label).join(", ");
    throw new Error(`Linux E2E failed for: ${names}`);
  }
}

export function selectLinuxTargets(target?: LinuxTarget): readonly LinuxTarget[] {
  return target === undefined ? STANDARD_LINUX_TARGETS : [target];
}

async function runLinuxTarget(
  target: LinuxTarget,
  staged: StagedSource,
  runId: string,
  signal: AbortSignal,
  beginSuccessfulCleanup: () => void,
): Promise<void> {
  const config = TARGETS[target];
  const containerName = `chezmoi-e2e-${target}-${runId}`;
  const volumeName = `${containerName}-home`;
  const logDirectory = join(cacheHome(), "chezmoi-e2e", "logs", runId, target);
  const stdoutLog = join(logDirectory, "stdout.log");
  const stderrLog = join(logDirectory, "stderr.log");
  const containerfile = join(moduleDirectory, config.containerfile);

  await Deno.mkdir(logDirectory, { recursive: true });
  await Deno.writeTextFile(
    join(logDirectory, "metadata.json"),
    `${
      JSON.stringify(
        {
          target,
          label: config.label,
          sourceSha256: staged.sha256,
          containerName,
          volumeName,
          capabilities: config.capabilities,
          privilegedSystemd: config.privilegedSystemd,
        },
        null,
        2,
      )
    }\n`,
  );

  const execute = async (step: string, builder: CommandBuilder) => {
    console.log(`step: ${step}`);
    try {
      await builder
        .stdout(createTee(stdoutLog, Deno.stdout))
        .stderr(createTee(stderrLog, Deno.stderr));
    } catch (error) {
      console.error(`step failed: ${step}`);
      throw error;
    }
  };

  console.log(`\n==> ${config.label}`);
  console.log(`logs: ${logDirectory}`);

  let completed = false;
  let archiveCopied = false;
  let sourcePrepared = false;
  let cleanupFailure: string | undefined;

  try {
    if (config.privilegedSystemd) {
      await execute(
        "preflight cgroup v2",
        command(["sh", "-c", "test $(stat -fc %T /sys/fs/cgroup) = cgroup2fs"]).signal(signal),
      );
    }

    const buildArguments = ["build", "--file", containerfile, "--tag", config.image];
    if (config.target !== undefined) buildArguments.push("--target", config.target);
    buildArguments.push(repository);
    await execute("build image", podman(config, buildArguments).signal(signal));
    await execute(
      "create home volume",
      podman(config, ["volume", "create", volumeName]).signal(signal),
    );

    const createArguments = [
      "create",
      "--name",
      containerName,
      "--volume",
      `${volumeName}:${config.home}:U`,
      "--env",
      "CHEZMOI_E2E=1",
      "--env",
      `CHEZMOI_E2E_RECIPIENT=${staged.recipient}`,
    ];
    if (config.privilegedSystemd) {
      createArguments.push(
        "--hostname",
        "cristina",
        "--privileged",
        "--systemd=always",
        config.image,
        "/sbin/init",
      );
    } else {
      createArguments.push("--env", "CHEZMOI_AGE_KEY", config.image);
    }
    let createCommand = podman(config, createArguments).signal(signal);
    if (!config.privilegedSystemd) {
      createCommand = createCommand.env({ CHEZMOI_AGE_KEY: staged.identity });
    }
    await execute("create container", createCommand);
    if (config.privilegedSystemd) {
      await execute(
        "copy age identity",
        podman(config, [
          "cp",
          staged.identityPath,
          `${containerName}:/usr/local/secrets/CHEZMOI_AGE_KEY`,
        ]).signal(signal),
      );
    }
    await execute(
      "copy source archive",
      podman(config, ["cp", staged.archivePath, `${containerName}:/tmp/source.tar`]).signal(signal),
    );
    archiveCopied = true;
    await execute("start container", podman(config, ["start", containerName]).signal(signal));

    if (config.privilegedSystemd) {
      await execute(
        "wait for user systemd",
        podman(config, [
          "exec",
          containerName,
          "/bin/sh",
          "-c",
          "for i in $(seq 1 60); do test -S /run/user/1000/bus && exit 0; sleep 1; done; exit 1",
        ]).signal(signal),
      );
      await execute(
        "prepare desktop runtime directory",
        podman(config, [
          "exec",
          containerName,
          "install",
          "-d",
          "-o",
          config.user,
          "-g",
          config.user,
          "/run/user/1000/X11-unix",
        ]).signal(signal),
      );
    }

    await execute(
      "prepare source directory",
      podman(config, [
        "exec",
        containerName,
        "/bin/sh",
        "-c",
        `mkdir -p /tmp/source && tar -xf /tmp/source.tar -C /tmp/source && chown -R ${config.user}:${config.user} /tmp/source ${config.home}${
          config.privilegedSystemd ? " /usr/local/secrets/CHEZMOI_AGE_KEY" : ""
        }`,
      ]).signal(signal),
    );
    sourcePrepared = true;
    await execute(
      "verify target environment",
      userExec(config, containerName, [
        "/bin/sh",
        "-c",
        environmentAssertion(config),
      ]).signal(signal),
    );
    await execute(
      "bootstrap with install.sh",
      userExec(config, containerName, [
        "/bin/sh",
        "-c",
        "cd /tmp/source && exec /bin/sh ./install.sh",
      ])
        .signal(signal),
    );
    await execute(
      "verify encrypted sentinel",
      userExec(config, containerName, [
        "/bin/sh",
        "-c",
        `sentinel=${config.home}/.config/chezmoi-e2e/sentinel.txt; test \"$(cat \"$sentinel\")\" = chezmoi-e2e-sentinel; test \"$(stat -c %a \"$sentinel\")\" = 600`,
      ]).signal(signal),
    );
    await execute(
      "verify initial target state",
      userExec(config, containerName, [
        `${config.home}/.local/bin/chezmoi`,
        "--source",
        "/tmp/source",
        "verify",
        "--exclude",
        "scripts",
      ]).signal(signal),
    );
    await execute(
      "verify platform symlinks",
      userExec(config, containerName, [
        "/bin/sh",
        "-c",
        `set -eu; code=${config.home}/.config/Code/User; test -L \"$code/settings.json\"; test \"$(readlink \"$code/settings.json\")\" = /tmp/source/home/dot_config/Code/User/managed/settings.json; test -L \"$code/keybindings.json\"; test \"$(readlink \"$code/keybindings.json\")\" = /tmp/source/home/dot_config/Code/User/managed/keybindings.json; test -L ${config.home}/.asdf; test \"$(readlink ${config.home}/.asdf)\" = ${config.home}/.local/share/mise`,
      ]).signal(signal),
    );
    await execute(
      "verify mise tools and externals",
      userExec(config, containerName, [
        "/bin/sh",
        "-c",
        `set -eu; test \"$(${config.home}/.local/bin/mise -C ${config.home} ls --missing --json)\" = '{}'; for command in age bat rg; do test -x ${config.home}/.local/bin/$command; done`,
      ]).signal(signal),
    );
    await execute(
      "verify idempotent dry run",
      userExec(config, containerName, [
        "/bin/bash",
        "-c",
        `set -euo pipefail; expected=$(printf '%s\\n' ' R .chezmoiscripts/linux/distrobox.sh' ' R .chezmoiscripts/linux/flatpak.sh'); actual=$(${config.home}/.local/bin/chezmoi --source /tmp/source status); test \"$actual\" = \"$expected\"; ${config.home}/.local/bin/chezmoi --source /tmp/source apply --dry-run --verbose`,
      ]).signal(signal),
    );
    await execute(
      "apply a second time",
      userExec(config, containerName, [
        `${config.home}/.local/bin/chezmoi`,
        "--source",
        "/tmp/source",
        "apply",
      ]).signal(signal),
    );
    await execute(
      "verify final target state",
      userExec(config, containerName, [
        `${config.home}/.local/bin/chezmoi`,
        "--source",
        "/tmp/source",
        "verify",
        "--exclude",
        "scripts",
      ]).signal(signal),
    );
    await verifyOutcomes(config, containerName, execute, signal);
    completed = true;
  } finally {
    if (completed) beginSuccessfulCleanup();

    if (completed) {
      const cleanup = await cleanupSuccessfulResources({
        presence: (kind) =>
          resourcePresence(config, kind, kind === "container" ? containerName : volumeName),
        remove: async (kind) => {
          const arguments_ = kind === "container"
            ? ["rm", "--force", containerName]
            : ["volume", "rm", volumeName];
          const result = await shieldedPodman(config, arguments_, cleanupTimeoutSeconds)
            .quiet()
            .noThrow();
          return result.code;
        },
      });
      if (cleanup.errors.length > 0) {
        reportRetainedResources(
          config,
          logDirectory,
          containerName,
          volumeName,
          cleanup.containerPresence,
          cleanup.volumePresence,
          archiveCopied,
          sourcePrepared,
        );
        cleanupFailure = cleanup.errors.join(", ");
      }
    } else {
      const [containerPresence, volumePresence] = await Promise.all([
        resourcePresence(config, "container", containerName),
        resourcePresence(config, "volume", volumeName),
      ]);
      if (containerPresence !== "absent" || volumePresence !== "absent") {
        reportRetainedResources(
          config,
          logDirectory,
          containerName,
          volumeName,
          containerPresence,
          volumePresence,
          archiveCopied,
          sourcePrepared,
        );
      }
    }
  }
  if (cleanupFailure !== undefined) throw new Error(`Linux E2E cleanup failed: ${cleanupFailure}`);
}

async function verifyOutcomes(
  config: TargetConfig,
  containerName: string,
  execute: (step: string, builder: CommandBuilder) => Promise<void>,
  signal: AbortSignal,
): Promise<void> {
  const mimeapps = `${config.home}/.config/mimeapps.list`;
  const handlerAssertion = config.capabilities.xdgDesktop
    ? `grep -Fqx x-scheme-handler/x-open-default=open-in-default-browser.desktop ${mimeapps}`
    : `test ! -e ${mimeapps} || ! grep -Fq x-scheme-handler/x-open-default= ${mimeapps}`;
  await execute(
    "verify x-open-default outcome",
    userExec(config, containerName, ["/bin/sh", "-c", handlerAssertion]).signal(signal),
  );

  if (config.capabilities.flatpak) {
    await execute(
      "verify Flatpak applications",
      userExec(config, containerName, [
        "/bin/bash",
        "-c",
        `set -euo pipefail; installed="$(flatpak list --system --app --columns=application,branch)"; while IFS=$'\\t' read -r id branch; do flatpak info --system "$id" >/dev/null; grep -Fqx "$id\t$branch" <<<"$installed"; done < <(chezmoi execute-template --source /tmp/source '{{ range .flatpak.apps }}{{ .id }}{{ "\\t" }}{{ .branch }}{{ "\\n" }}{{ end }}')`,
      ]).signal(signal),
    );
  }

  if (config.capabilities.distrobox) {
    await execute(
      "verify Distrobox applications",
      userExec(config, containerName, [
        "/bin/bash",
        "-c",
        `set -euo pipefail; containers="$(distrobox list --no-color)"; for name in dms noctalia scroll; do grep -Eq "(^|[[:space:]|])$name([[:space:]|]|$)" <<<"$containers"; test -f ${config.home}/.local/state/chezmoi/distrobox/$name.applied; done`,
      ]).signal(signal),
    );
  }
}

function environmentAssertion(config: TargetConfig): string {
  const capability = (name: string, expected: boolean) =>
    expected ? `command -v ${name} >/dev/null` : `! command -v ${name} >/dev/null`;
  return [
    "set -eu",
    `. /etc/os-release`,
    `test \"$ID\" = ${config.osId}`,
    `test \"$VERSION_ID\" = ${config.versionId}`,
    `test \"$(id -un)\" = ${config.user}`,
    `test \"$HOME\" = ${config.home}`,
    capability("flatpak", config.capabilities.flatpak),
    capability("distrobox", config.capabilities.distrobox),
    capability("xdg-mime", config.capabilities.xdgDesktop),
    capability("update-desktop-database", config.capabilities.xdgDesktop),
  ].join("; ");
}

function userExec(
  config: TargetConfig,
  containerName: string,
  arguments_: string[],
): CommandBuilder {
  return podman(config, ["exec", "--user", config.user, containerName, ...arguments_]);
}

function podman(_config: TargetConfig, arguments_: string[]): CommandBuilder {
  return command(["podman", ...arguments_]);
}

function shieldedPodman(
  _config: TargetConfig,
  arguments_: string[],
  timeoutSeconds: number,
): CommandBuilder {
  return command([
    "timeout",
    "--signal=TERM",
    "--kill-after=5s",
    `${timeoutSeconds}s`,
    "sh",
    "-c",
    signalShieldedExec,
    "sh",
    "podman",
    ...arguments_,
  ]);
}

function command(arguments_: string[]): CommandBuilder {
  return new CommandBuilder().command(arguments_);
}

async function resourcePresence(
  config: TargetConfig,
  kind: "container" | "volume",
  name: string,
): Promise<ResourcePresence> {
  const result = await shieldedPodman(config, [kind, "exists", name], presenceTimeoutSeconds)
    .quiet().noThrow();
  if (result.code === 0) return "present";
  if (result.code === 1) return "absent";
  return "unknown";
}

function reportRetainedResources(
  config: TargetConfig,
  logDirectory: string,
  containerName: string,
  volumeName: string,
  containerPresence: ResourcePresence,
  volumePresence: ResourcePresence,
  archiveCopied: boolean,
  sourcePrepared: boolean,
): void {
  console.error(retainedResourceReport({
    archiveCopied,
    containerName,
    containerPresence,
    home: config.home,
    logDirectory,
    privilegedSystemd: config.privilegedSystemd,
    sourcePrepared,
    user: config.user,
    volumeName,
    volumePresence,
  }));
}

class InterruptedError extends Error {
  constructor(signal: Deno.Signal, options?: ErrorOptions) {
    super(`interrupted by ${signal}`, options);
    this.name = "InterruptedError";
  }
}

function cacheHome(): string {
  const xdgCacheHome = Deno.env.get("XDG_CACHE_HOME");
  if (xdgCacheHome) return xdgCacheHome;

  const home = Deno.env.get("HOME");
  if (!home) throw new Error("HOME is not set and XDG_CACHE_HOME is unavailable");
  return join(home, ".cache");
}

function createTee(
  path: string,
  output: { write(data: Uint8Array): Promise<number> },
): WritableStream<Uint8Array> {
  let file: Deno.FsFile;

  return new WritableStream({
    start() {
      file = Deno.openSync(path, { append: true, create: true, write: true, mode: 0o600 });
    },
    async write(chunk) {
      await Promise.all([file.write(chunk), output.write(chunk)]);
    },
    close() {
      file.close();
    },
    abort() {
      file.close();
    },
  });
}
