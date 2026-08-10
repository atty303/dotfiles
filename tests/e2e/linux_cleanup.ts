export type ResourceKind = "container" | "volume";
export type ResourcePresence = "present" | "absent" | "unknown";

export interface CleanupOperations {
  presence(kind: ResourceKind): Promise<ResourcePresence>;
  remove(kind: ResourceKind): Promise<number>;
}

export interface CleanupResult {
  containerPresence: ResourcePresence;
  errors: readonly string[];
  volumePresence: ResourcePresence;
}

export async function cleanupSuccessfulResources(
  operations: CleanupOperations,
): Promise<CleanupResult> {
  let containerPresence = await operations.presence("container");
  let volumePresence = await operations.presence("volume");
  const errors: string[] = [];
  let containerRemoved = containerPresence === "absent";

  if (!containerRemoved) {
    const code = await operations.remove("container");
    if (code !== 0) {
      errors.push(`container cleanup exited ${code}`);
    } else {
      containerPresence = await operations.presence("container");
      containerRemoved = containerPresence === "absent";
      if (!containerRemoved) {
        errors.push(`container cleanup left resource ${containerPresence}`);
      }
    }
  }

  if (containerRemoved && volumePresence !== "absent") {
    const code = await operations.remove("volume");
    if (code !== 0) {
      errors.push(`volume cleanup exited ${code}`);
    } else {
      volumePresence = await operations.presence("volume");
      if (volumePresence !== "absent") {
        errors.push(`volume cleanup left resource ${volumePresence}`);
      }
    }
  }

  if (errors.length > 0) {
    [containerPresence, volumePresence] = await Promise.all([
      operations.presence("container"),
      operations.presence("volume"),
    ]);
  }

  return { containerPresence, errors, volumePresence };
}

export interface RetainedResourceReportOptions {
  archiveCopied: boolean;
  containerName: string;
  containerPresence: ResourcePresence;
  home: string;
  logDirectory: string;
  privilegedSystemd: boolean;
  sourcePrepared: boolean;
  user: string;
  volumeName: string;
  volumePresence: ResourcePresence;
}

export function retainedResourceReport(options: RetainedResourceReportOptions): string {
  const lines = [
    "",
    "E2E resources retained for investigation:",
    `  logs: ${options.logDirectory}`,
    `  container: ${options.containerName} (${options.containerPresence})`,
    `  volume: ${options.volumeName} (${options.volumePresence})`,
  ];
  if (options.containerPresence !== "absent") {
    lines.push(
      `  start (if stopped): podman start ${options.containerName}`,
      `  shell: podman exec -it ${options.containerName} /bin/bash`,
    );
    if (options.sourcePrepared) {
      lines.push(
        `  retry install: podman exec --user ${options.user} ${options.containerName} /bin/sh -c 'if test -x ${options.home}/.local/bin/mise; then ${options.home}/.local/bin/mise trust /tmp/source/mise.toml; fi; cd /tmp/source && exec /bin/sh ./install.sh'`,
      );
    } else if (options.archiveCopied) {
      lines.push(
        `  prepare source: podman exec ${options.containerName} /bin/sh -c 'mkdir -p /tmp/source && tar -xf /tmp/source.tar -C /tmp/source && chown -R ${options.user}:${options.user} /tmp/source ${options.home}${
          options.privilegedSystemd ? " /usr/local/secrets/CHEZMOI_AGE_KEY" : ""
        }'`,
        `  retry install after preparation: podman exec --user ${options.user} ${options.containerName} /bin/sh -c 'if test -x ${options.home}/.local/bin/mise; then ${options.home}/.local/bin/mise trust /tmp/source/mise.toml; fi; cd /tmp/source && exec /bin/sh ./install.sh'`,
      );
    } else {
      lines.push("  source archive: not copied; inspect the logs before retrying");
    }
    lines.push(`  remove container: podman rm --force ${options.containerName}`);
  }
  if (options.volumePresence !== "absent") {
    lines.push(`  remove volume: podman volume rm ${options.volumeName}`);
  }
  return lines.join("\n");
}
