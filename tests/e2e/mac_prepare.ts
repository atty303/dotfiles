import { MAC_E2E } from "./mac_config.ts";
import { dirname, join, resolve } from "node:path";

const READY_TIMEOUT_MS = 5 * 60 * 1000;
const READY_INTERVAL_MS = 2_000;

export async function prepareMacHost(): Promise<void> {
  const abort = new AbortController();
  const interrupt = () => abort.abort(new Error("received SIGINT"));
  const terminate = () => abort.abort(new Error("received SIGTERM"));
  Deno.addSignalListener("SIGINT", interrupt);
  Deno.addSignalListener("SIGTERM", terminate);
  const finalErrors: unknown[] = [];
  let workspace: TartWorkspace | undefined;

  try {
    const host = await inspectHost();
    workspace = await createTartWorkspace();
    const probeName = `chezmoi-e2e-prepare-${crypto.randomUUID().slice(0, 8)}`;
    let runProcess: Deno.ChildProcess | undefined;
    let operationError: unknown;

    console.log(`macOS ${host.version} (${host.architecture})`);
    console.log(`logical CPUs: ${host.cpuCount}`);
    console.log(`physical memory: ${formatGiB(host.memoryBytes)}`);
    console.log(`available disk for Tart: ${formatGiB(host.availableDiskBytes)}`);
    console.log(`image: ${MAC_E2E.image}`);

    try {
      assertHostCapacity(host);
      await run("security", [
        "show-keychain-info",
        `${requiredEnvironment("HOME")}/Library/Keychains/login.keychain-db`,
      ], {
        failure:
          "The login keychain is unavailable. Log in to this user in the macOS GUI and unlock the login keychain.",
        signal: abort.signal,
      });
      await run("tart", ["pull", MAC_E2E.image], {
        failure:
          "Tart could not pull the pinned image. Verify network access and that the login keychain is unlocked.",
        signal: abort.signal,
      });
      await run("tart", ["clone", MAC_E2E.image, probeName], { signal: abort.signal });
      await run("tart", [
        "set",
        probeName,
        "--cpu",
        String(MAC_E2E.cpuCount),
        "--memory",
        String(MAC_E2E.memoryMiB),
      ], { signal: abort.signal });

      runProcess = new Deno.Command("tart", {
        args: ["run", "--no-graphics", "--no-audio", "--no-clipboard", probeName],
        stdin: "null",
        stdout: "inherit",
        stderr: "inherit",
      }).spawn();

      await waitForGuestAgent(probeName, runProcess, abort.signal);
      console.log("Tart macOS E2E host is ready.");
    } catch (error) {
      operationError = error;
    }

    const errors: unknown[] = operationError === undefined ? [] : [operationError];
    if (runProcess !== undefined) {
      try {
        await run("tart", ["stop", "--timeout", "30", probeName], {
          signal: AbortSignal.timeout(35_000),
        });
      } catch (error) {
        errors.push(error);
      }
      try {
        await finishProcess(runProcess);
      } catch (error) {
        errors.push(error);
      }
    }
    let vmPresent = false;
    try {
      vmPresent = await pathExists(join(tartStoragePath(), "vms", probeName));
    } catch (error) {
      errors.push(error);
    }
    if (vmPresent) {
      try {
        await run("tart", ["delete", probeName], { signal: AbortSignal.timeout(30_000) });
      } catch (error) {
        errors.push(error);
      }
    }

    finalErrors.push(...errors);
  } catch (error) {
    finalErrors.push(error);
  } finally {
    if (workspace !== undefined) {
      try {
        restoreTartHome(workspace.originalTartHome);
      } catch (error) {
        finalErrors.push(error);
      }
      try {
        await Deno.remove(workspace.runHome, { recursive: true });
      } catch (error) {
        finalErrors.push(error);
      }
    }
    Deno.removeSignalListener("SIGINT", interrupt);
    Deno.removeSignalListener("SIGTERM", terminate);
  }

  if (finalErrors.length === 1) throw finalErrors[0];
  if (finalErrors.length > 1) {
    throw new AggregateError(finalErrors, "Mac E2E preparation failed");
  }
}

interface HostInfo {
  architecture: string;
  availableDiskBytes: number;
  cpuCount: number;
  memoryBytes: number;
  version: string;
}

interface TartWorkspace {
  originalTartHome: string | undefined;
  runHome: string;
}

async function inspectHost(): Promise<HostInfo> {
  if (Deno.build.os !== "darwin") {
    throw new Error("macOS E2E preparation must run on macOS");
  }

  const storagePath = await existingAncestor(tartStoragePath());
  const [architecture, version, cpuCount, memoryBytes, availableDiskBlocks] = await Promise.all([
    output("uname", ["-m"]),
    output("sw_vers", ["-productVersion"]),
    output("sysctl", ["-n", "hw.logicalcpu"]),
    output("sysctl", ["-n", "hw.memsize"]),
    output("df", ["-Pk", storagePath]).then((value) => {
      const fields = value.trim().split("\n").at(-1)?.trim().split(/\s+/);
      if (fields === undefined || fields.length < 4) throw new Error("unexpected df output");
      return fields[3];
    }),
  ]);

  return {
    architecture,
    availableDiskBytes: parsePositiveInteger(availableDiskBlocks, "available disk blocks") * 1024,
    cpuCount: parsePositiveInteger(cpuCount, "logical CPU count"),
    memoryBytes: parsePositiveInteger(memoryBytes, "physical memory"),
    version,
  };
}

function assertHostCapacity(host: HostInfo): void {
  if (host.architecture !== "arm64") {
    throw new Error(`Tart macOS E2E requires Apple Silicon, found ${host.architecture}`);
  }

  const majorVersion = parsePositiveInteger(host.version.split(".")[0], "macOS major version");
  if (majorVersion < 14) {
    throw new Error(`tart exec requires macOS 14 or later, found ${host.version}`);
  }
  if (host.cpuCount < MAC_E2E.cpuCount) {
    throw new Error(`macOS E2E requires at least ${MAC_E2E.cpuCount} logical CPUs`);
  }

  const requiredMemory = MAC_E2E.memoryMiB * 1024 * 1024;
  if (host.memoryBytes < requiredMemory) {
    throw new Error(`macOS E2E requires at least ${formatGiB(requiredMemory)} of physical memory`);
  }
  if (host.availableDiskBytes < MAC_E2E.minimumAvailableDiskBytes) {
    throw new Error(
      `macOS E2E requires at least ${
        formatGiB(MAC_E2E.minimumAvailableDiskBytes)
      } of available disk`,
    );
  }
}

async function waitForGuestAgent(
  name: string,
  process: Deno.ChildProcess,
  signal: AbortSignal,
): Promise<void> {
  const deadline = Date.now() + READY_TIMEOUT_MS;

  while (Date.now() < deadline) {
    signal.throwIfAborted();
    const processStatus = await Promise.race([
      process.status.then((status) => ({ kind: "exited" as const, status })),
      delay(0).then(() => ({ kind: "running" as const })),
    ]);
    if (processStatus.kind === "exited") {
      throw new Error(
        `Tart VM exited before the guest agent was ready (${processStatus.status.code})`,
      );
    }

    const remainingMs = deadline - Date.now();
    const execSignal = AbortSignal.any([signal, AbortSignal.timeout(remainingMs)]);
    let result: Deno.CommandOutput;
    try {
      result = await command("tart", ["exec", name, "/usr/bin/uname", "-s"], execSignal);
    } catch (error) {
      signal.throwIfAborted();
      if (Date.now() >= deadline || execSignal.aborted) break;
      throw error;
    }
    if (result.success && new TextDecoder().decode(result.stdout).trim() === "Darwin") return;
    await delay(READY_INTERVAL_MS, signal);
  }

  throw new Error(`Tart guest agent was not ready within ${READY_TIMEOUT_MS / 1000} seconds`);
}

interface RunOptions {
  allowFailure?: boolean;
  failure?: string;
  signal?: AbortSignal;
}

async function run(commandName: string, args: string[], options: RunOptions = {}): Promise<void> {
  const process = new Deno.Command(commandName, {
    args,
    stdin: "null",
    stdout: "inherit",
    stderr: "inherit",
  }).spawn();
  const result = await waitForCommand(process, process.status, options.signal);
  if (!result.success && !options.allowFailure) {
    throw new Error(
      options.failure ?? `${commandName} ${args[0]} failed with exit code ${result.code}`,
    );
  }
}

async function output(commandName: string, args: string[]): Promise<string> {
  const result = await command(commandName, args);
  if (!result.success) throw new Error(`${commandName} failed with exit code ${result.code}`);
  return new TextDecoder().decode(result.stdout).trim();
}

function command(
  commandName: string,
  args: string[],
  signal?: AbortSignal,
): Promise<Deno.CommandOutput> {
  const process = new Deno.Command(commandName, {
    args,
    stdin: "null",
    stdout: "piped",
    stderr: "piped",
  }).spawn();
  return waitForCommand(process, process.output(), signal);
}

async function waitForCommand<T>(
  process: Deno.ChildProcess,
  completion: Promise<T>,
  signal?: AbortSignal,
): Promise<T> {
  if (signal === undefined) return completion;

  try {
    return await waitForAbort(completion, signal);
  } catch (error) {
    if (!signal.aborted) throw error;

    try {
      await terminateCommand(process, completion);
    } catch (terminationError) {
      throw new AggregateError(
        [error, terminationError],
        "Command deadline expired and process termination failed",
      );
    }
    throw error;
  }
}

function waitForAbort<T>(completion: Promise<T>, signal: AbortSignal): Promise<T> {
  signal.throwIfAborted();

  return new Promise((resolve, reject) => {
    const onAbort = () => reject(signal.reason);
    signal.addEventListener("abort", onAbort, { once: true });
    completion.then(
      (result) => {
        signal.removeEventListener("abort", onAbort);
        resolve(result);
      },
      (error) => {
        signal.removeEventListener("abort", onAbort);
        reject(error);
      },
    );
  });
}

async function terminateCommand<T>(
  process: Deno.ChildProcess,
  completion: Promise<T>,
): Promise<void> {
  try {
    process.kill("SIGTERM");
  } catch (killError) {
    if (await completionSettledWithin(completion, 250)) return;
    throw killError;
  }
  if (await completionSettledWithin(completion, 2_000)) return;

  try {
    process.kill("SIGKILL");
  } catch (killError) {
    if (await completionSettledWithin(completion, 250)) return;
    throw killError;
  }
  if (!await completionSettledWithin(completion, 5_000)) {
    throw new Error("Command process did not exit after SIGKILL");
  }
}

function completionSettledWithin<T>(
  completion: Promise<T>,
  milliseconds: number,
): Promise<boolean> {
  return Promise.race([
    completion.then(() => true),
    delay(milliseconds).then(() => false),
  ]);
}

function parsePositiveInteger(value: string, label: string): number {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) throw new Error(`invalid ${label}: ${value}`);
  return parsed;
}

function formatGiB(bytes: number): string {
  return `${(bytes / 1024 / 1024 / 1024).toFixed(1)} GiB`;
}

function delay(milliseconds: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const abortSignal = signal;
    const onAbort = () => {
      clearTimeout(timeout);
      reject(abortSignal?.reason);
    };
    const timeout = setTimeout(() => {
      signal?.removeEventListener("abort", onAbort);
      resolve();
    }, milliseconds);
    signal?.addEventListener("abort", onAbort, { once: true });
  });
}

async function finishProcess(process: Deno.ChildProcess | undefined): Promise<void> {
  if (process === undefined) return;

  const finished = await processFinishedWithin(process, 5_000);
  if (finished) return;

  try {
    process.kill("SIGKILL");
  } catch (killError) {
    let exited: boolean;
    try {
      exited = await processFinishedWithin(process, 1_000);
    } catch (statusError) {
      throw new AggregateError(
        [killError, statusError],
        "Failed to kill the Tart VM process and confirm its status",
      );
    }
    if (exited) return;
    throw killError;
  }
  const killed = await processFinishedWithin(process, 5_000);
  if (!killed) throw new Error("Tart VM process did not exit after SIGKILL");
}

function processFinishedWithin(
  process: Deno.ChildProcess,
  milliseconds: number,
): Promise<boolean> {
  return Promise.race([
    process.status.then(() => true),
    delay(milliseconds).then(() => false),
  ]);
}

function tartStoragePath(): string {
  const custom = Deno.env.get("TART_HOME");
  return custom === undefined || custom === ""
    ? join(requiredEnvironment("HOME"), ".tart")
    : resolve(custom);
}

async function createTartWorkspace(): Promise<TartWorkspace> {
  const originalTartHome = Deno.env.get("TART_HOME");
  const persistentHome = tartStoragePath();
  const persistentCache = join(persistentHome, "cache");
  await Deno.mkdir(persistentCache, { recursive: true });
  const runHome = await Deno.makeTempDir({ dir: persistentHome, prefix: "chezmoi-e2e-" });

  try {
    await Deno.symlink(persistentCache, join(runHome, "cache"));
  } catch (error) {
    try {
      await Deno.remove(runHome, { recursive: true });
    } catch (rollbackError) {
      throw new AggregateError(
        [error, rollbackError],
        "Failed to create and roll back the Tart workspace",
      );
    }
    throw error;
  }

  Deno.env.set("TART_HOME", runHome);
  return { originalTartHome, runHome };
}

function restoreTartHome(original: string | undefined): void {
  if (original === undefined) {
    Deno.env.delete("TART_HOME");
  } else {
    Deno.env.set("TART_HOME", original);
  }
}

async function existingAncestor(path: string): Promise<string> {
  let candidate = path;
  while (true) {
    try {
      await Deno.stat(candidate);
      return candidate;
    } catch (error) {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
    }

    const parent = dirname(candidate);
    if (parent === candidate) throw new Error(`no existing ancestor for ${path}`);
    candidate = parent;
  }
}

async function pathExists(path: string): Promise<boolean> {
  try {
    await Deno.stat(path);
    return true;
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return false;
    throw error;
  }
}

function requiredEnvironment(name: string): string {
  const value = Deno.env.get(name);
  if (value === undefined || value === "") throw new Error(`${name} is not set`);
  return value;
}
