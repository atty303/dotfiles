import { $, type CommandBuilder } from "@david/dax";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { type StagedSource, stageSource } from "./staging.ts";

export type LinuxTarget = "fedora" | "ubuntu";

interface TargetConfig {
  containerfile: string;
  image: string;
  label: string;
}

const TARGETS: Record<LinuxTarget, TargetConfig> = {
  fedora: {
    containerfile: "containers/fedora-44.Containerfile",
    image: "localhost/chezmoi-e2e-fedora:44",
    label: "Fedora 44",
  },
  ubuntu: {
    containerfile: "containers/ubuntu-24.04.Containerfile",
    image: "localhost/chezmoi-e2e-ubuntu:24.04",
    label: "Ubuntu 24.04",
  },
};

const moduleDirectory = dirname(fileURLToPath(import.meta.url));
const repository = join(moduleDirectory, "..", "..");
const signalShieldedExec = 'trap "" HUP INT TERM; exec "$@"';

export async function runLinuxTargets(target: LinuxTarget | "all"): Promise<void> {
  const targets: LinuxTarget[] = target === "all" ? ["fedora", "ubuntu"] : [target];
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
    const names = failures.map(({ target: failedTarget }) => TARGETS[failedTarget].label).join(
      ", ",
    );
    throw new Error(`Linux E2E failed for: ${names}`);
  }
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
  let cleanupFailure: string | undefined;

  try {
    await execute(
      "build image",
      $`podman build --file ${containerfile} --tag ${config.image} ${repository}`.signal(
        signal,
      ),
    );
    await execute("create home volume", $`podman volume create ${volumeName}`.signal(signal));
    await execute(
      "create container",
      $`podman create --name ${containerName} --volume ${volumeName}:/home/e2e:U --env CHEZMOI_AGE_KEY --env CHEZMOI_E2E=1 --env CHEZMOI_E2E_RECIPIENT=${staged.recipient} ${config.image}`
        .env({ CHEZMOI_AGE_KEY: staged.identity })
        .signal(signal),
    );
    await execute(
      "copy source archive",
      $`podman cp ${staged.archivePath} ${containerName}:/tmp/source.tar`.signal(signal),
    );
    archiveCopied = true;
    await execute("start container", $`podman start ${containerName}`.signal(signal));
    await execute(
      "create source directory",
      $`podman exec ${containerName} mkdir -p /tmp/source`.signal(signal),
    );
    await execute(
      "extract source archive",
      $`podman exec ${containerName} tar -xf /tmp/source.tar -C /tmp/source`.signal(signal),
    );
    await execute(
      "bootstrap with install.sh",
      $`podman exec --workdir /tmp/source ${containerName} /bin/sh ./install.sh`.signal(
        signal,
      ),
    );
    await execute(
      "verify initial target state",
      $`podman exec ${containerName} /home/e2e/.local/bin/chezmoi --source /tmp/source verify --exclude scripts`
        .signal(
          signal,
        ),
    );
    await execute(
      "apply a second time",
      $`podman exec ${containerName} /home/e2e/.local/bin/chezmoi --source /tmp/source apply`
        .signal(
          signal,
        ),
    );
    await execute(
      "verify final target state",
      $`podman exec ${containerName} /home/e2e/.local/bin/chezmoi --source /tmp/source verify --exclude scripts`
        .signal(
          signal,
        ),
    );
    completed = true;
  } finally {
    if (completed) beginSuccessfulCleanup();
    let containerPresence = await resourcePresence("container", containerName);
    let volumePresence = await resourcePresence("volume", volumeName);

    if (completed) {
      const cleanupErrors: string[] = [];
      let containerRemoved = containerPresence === "absent";
      if (containerPresence !== "absent") {
        const result =
          await $`sh -c ${signalShieldedExec} sh setsid --fork --wait podman rm --force ${containerName}`
            .quiet().noThrow();
        if (result.code !== 0) {
          cleanupErrors.push(`container cleanup exited ${result.code}`);
        } else {
          containerPresence = await resourcePresence("container", containerName);
          containerRemoved = containerPresence === "absent";
          if (!containerRemoved) {
            cleanupErrors.push(`container cleanup left resource ${containerPresence}`);
          }
        }
      }
      if (containerRemoved && volumePresence !== "absent") {
        const result =
          await $`sh -c ${signalShieldedExec} sh setsid --fork --wait podman volume rm ${volumeName}`
            .quiet().noThrow();
        if (result.code !== 0) cleanupErrors.push(`volume cleanup exited ${result.code}`);
      }
      if (cleanupErrors.length > 0) {
        containerPresence = await resourcePresence("container", containerName);
        volumePresence = await resourcePresence("volume", volumeName);
        reportRetainedResources(
          logDirectory,
          containerName,
          volumeName,
          containerPresence,
          volumePresence,
          archiveCopied,
        );
        cleanupFailure = cleanupErrors.join(", ");
      }
    } else if (containerPresence !== "absent" || volumePresence !== "absent") {
      reportRetainedResources(
        logDirectory,
        containerName,
        volumeName,
        containerPresence,
        volumePresence,
        archiveCopied,
      );
    }
  }
  if (cleanupFailure !== undefined) {
    throw new Error(`Linux E2E cleanup failed: ${cleanupFailure}`);
  }
}

type ResourcePresence = "present" | "absent" | "unknown";

async function resourcePresence(
  kind: "container" | "volume",
  name: string,
): Promise<ResourcePresence> {
  const result = kind === "container"
    ? await $`sh -c ${signalShieldedExec} sh setsid --fork --wait podman container exists ${name}`
      .quiet().noThrow()
    : await $`sh -c ${signalShieldedExec} sh setsid --fork --wait podman volume exists ${name}`
      .quiet().noThrow();
  if (result.code === 0) return "present";
  if (result.code === 1) return "absent";
  return "unknown";
}

function reportRetainedResources(
  logDirectory: string,
  containerName: string,
  volumeName: string,
  containerPresence: ResourcePresence,
  volumePresence: ResourcePresence,
  archiveCopied: boolean,
): void {
  const lines = [
    "",
    "E2E resources retained for investigation:",
    `  logs: ${logDirectory}`,
    `  container: ${containerName} (${containerPresence})`,
    `  volume: ${volumeName} (${volumePresence})`,
  ];
  if (containerPresence !== "absent") {
    lines.push(
      `  start (if stopped): podman start ${containerName}`,
      `  shell: podman exec -it ${containerName} /bin/bash`,
    );
    if (archiveCopied) {
      lines.push(
        `  prepare source: podman exec ${containerName} mkdir -p /tmp/source`,
        `  extract source: podman exec ${containerName} tar -xf /tmp/source.tar -C /tmp/source`,
        `  retry install: podman exec --workdir /tmp/source ${containerName} /bin/sh ./install.sh`,
      );
    } else {
      lines.push("  source archive: not copied; inspect the logs before retrying");
    }
    lines.push(`  remove container: podman rm --force ${containerName}`);
  }
  if (volumePresence !== "absent") {
    lines.push(`  remove volume: podman volume rm ${volumeName}`);
  }
  console.error(lines.join("\n"));
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
