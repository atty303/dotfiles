import { join } from "node:path";
import { runMacVm } from "./mac_prepare.ts";
import { type StagedSource, stageSource } from "./staging.ts";

const GUEST_MOUNT = "/Volumes/My Shared Files/e2e";
const GUEST_LOG_MOUNT = "/Volumes/My Shared Files/logs";
const GUEST_TIMEOUT_MS = 2 * 60 * 60 * 1000;

export async function runMacLocal(): Promise<void> {
  const abort = new AbortController();
  const signals = registerSignals(abort);
  let staged: StagedSource | undefined;

  const errors: unknown[] = [];
  try {
    staged = await stageSource(abort.signal);
    await runStagedMac(staged);
  } catch (error) {
    errors.push(error);
  } finally {
    if (staged !== undefined) {
      try {
        await Deno.remove(staged.tempDir, { recursive: true });
      } catch (error) {
        errors.push(error);
      }
    }
    signals.remove();
  }
  throwCollected(errors, "Local macOS E2E failed");
}

async function runStagedMac(staged: StagedSource): Promise<void> {
  console.log(`source archive sha256: ${staged.sha256}`);
  const logDirectory = Deno.env.get("CHEZMOI_E2E_LOG_DIRECTORY") ??
    join(cacheHome(), "chezmoi-e2e", "logs", createRunId(), "macos");
  await Deno.mkdir(logDirectory, { recursive: true });
  await Deno.writeTextFile(
    join(logDirectory, "metadata.json"),
    `${JSON.stringify({ target: "macos", sourceSha256: staged.sha256 }, null, 2)}\n`,
  );
  console.log(`logs: ${logDirectory}`);

  await runMacVm({
    namePrefix: "macos",
    sharedDirectories: [
      { name: "e2e", path: staged.tempDir, readOnly: true },
      { name: "logs", path: logDirectory, readOnly: false },
    ],
  }, async (vm) => {
    const sourceDirectory = "/tmp/chezmoi-e2e-source";
    await vm.run(["/bin/mkdir", "-p", sourceDirectory]);
    await vm.run([
      "/usr/bin/tar",
      "-xf",
      `${GUEST_MOUNT}/source.tar`,
      "-C",
      sourceDirectory,
    ]);
    await vm.run([
      "/bin/bash",
      `${sourceDirectory}/tests/e2e/mac_guest.sh`,
      sourceDirectory,
      `${GUEST_MOUNT}/identity.txt`,
      staged.recipient,
      GUEST_LOG_MOUNT,
    ], GUEST_TIMEOUT_MS);
  });
}

interface RegisteredSignals {
  remove(): void;
}

function registerSignals(abort: AbortController): RegisteredSignals {
  const hangup = () => abort.abort(new Error("received SIGHUP"));
  const interrupt = () => abort.abort(new Error("received SIGINT"));
  const terminate = () => abort.abort(new Error("received SIGTERM"));
  Deno.addSignalListener("SIGHUP", hangup);
  Deno.addSignalListener("SIGINT", interrupt);
  Deno.addSignalListener("SIGTERM", terminate);
  return {
    remove() {
      Deno.removeSignalListener("SIGHUP", hangup);
      Deno.removeSignalListener("SIGINT", interrupt);
      Deno.removeSignalListener("SIGTERM", terminate);
    },
  };
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value === "") throw new Error(`${name} is not set`);
  return value;
}

function throwCollected(errors: unknown[], message: string): void {
  if (errors.length === 1) throw errors[0];
  if (errors.length > 1) throw new AggregateError(errors, message);
}

function createRunId(): string {
  return `${new Date().toISOString().replaceAll(/[-:.TZ]/g, "")}-${
    crypto.randomUUID().slice(0, 8)
  }`;
}

function cacheHome(): string {
  const xdgCacheHome = Deno.env.get("XDG_CACHE_HOME");
  if (xdgCacheHome) return xdgCacheHome;
  return join(requiredEnvironment("HOME"), ".cache");
}
