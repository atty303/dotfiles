import { join } from "node:path";
import { runMacVm, waitForCommand } from "./mac_prepare.ts";
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

export async function runMacHost(stagingDirectory: string, recipient: string): Promise<void> {
  assertRecipient(recipient);
  const archivePath = join(stagingDirectory, "source.tar");
  const identityPath = join(stagingDirectory, "identity.txt");
  await Promise.all([Deno.stat(archivePath), Deno.stat(identityPath)]);
  await Deno.chmod(identityPath, 0o600);

  await runStagedMac({
    archivePath,
    identity: "",
    identityPath,
    recipient,
    sha256: await sha256(archivePath),
    tempDir: stagingDirectory,
  });
}

export async function runMacLan(): Promise<void> {
  if (Deno.build.os === "darwin") {
    throw new Error("Use test:e2e:mac:local when running on macOS");
  }

  const host = requiredEnvironment("E2E_MAC_HOST");
  assertSshHost(host);
  const abort = new AbortController();
  const signals = registerSignals(abort);
  let remoteDirectory: string | undefined;
  const runId = createRunId();
  const localLogDirectory = join(cacheHome(), "chezmoi-e2e", "logs", runId, "macos");
  let staged: StagedSource | undefined;

  const errors: unknown[] = [];
  try {
    staged = await stageSource(abort.signal);
    remoteDirectory = await remoteTempDirectory(host, abort.signal);
    const inputDirectory = `${remoteDirectory}/input`;
    const runnerDirectory = `${remoteDirectory}/runner`;
    const remoteLogDirectory = `${remoteDirectory}/logs`;

    await ssh(
      host,
      ["mkdir", "-p", inputDirectory, runnerDirectory, remoteLogDirectory],
      abort.signal,
    );
    await scp(host, [staged.archivePath, staged.identityPath], inputDirectory, abort.signal);
    await ssh(host, ["chmod", "600", `${inputDirectory}/identity.txt`], abort.signal);
    await ssh(
      host,
      ["tar", "-xf", `${inputDirectory}/source.tar`, "-C", runnerDirectory],
      abort.signal,
    );

    await ssh(host, [
      "/bin/bash",
      `${runnerDirectory}/tests/e2e/mac_remote.sh`,
      "launch",
      runnerDirectory,
      inputDirectory,
      staged.recipient,
      remoteLogDirectory,
    ], abort.signal);
  } catch (error) {
    errors.push(error);
  } finally {
    if (remoteDirectory !== undefined) {
      try {
        await Deno.mkdir(localLogDirectory, { recursive: true });
        await downloadDirectory(
          host,
          `${remoteDirectory}/logs`,
          localLogDirectory,
          AbortSignal.timeout(60_000),
        );
        console.log(`logs: ${localLogDirectory}`);
      } catch (error) {
        errors.push(error);
      }
      try {
        await ssh(host, ["rm", "-rf", remoteDirectory], AbortSignal.timeout(30_000));
      } catch (error) {
        errors.push(error);
      }
    }
    if (staged !== undefined) {
      try {
        await Deno.remove(staged.tempDir, { recursive: true });
      } catch (error) {
        errors.push(error);
      }
    }
    signals.remove();
  }
  throwCollected(errors, "LAN macOS E2E failed");
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

async function remoteTempDirectory(host: string, signal: AbortSignal): Promise<string> {
  const result = await output(
    "ssh",
    [...sshOptions(), host, "mktemp", "-d", "-t", "chezmoi-e2e"],
    signal,
  );
  const path = result.trim();
  if (
    !/^\/var\/folders\/[A-Za-z0-9._-]+\/[A-Za-z0-9._-]+\/T\/chezmoi-e2e\.[A-Za-z0-9._-]+$/
      .test(path)
  ) {
    throw new Error(`unexpected remote temporary directory: ${path}`);
  }
  return path;
}

function ssh(host: string, args: string[], signal?: AbortSignal): Promise<void> {
  return run("ssh", [...sshOptions(), host, ...args], signal);
}

function scp(
  host: string,
  paths: string[],
  remoteDirectory: string,
  signal: AbortSignal,
): Promise<void> {
  return run("scp", [...sshOptions(), ...paths, `${host}:${remoteDirectory}/`], signal);
}

function downloadDirectory(
  host: string,
  remoteDirectory: string,
  localDirectory: string,
  signal: AbortSignal,
): Promise<void> {
  return run(
    "scp",
    [...sshOptions(), "-r", `${host}:${remoteDirectory}/.`, `${localDirectory}/`],
    signal,
  );
}

function sshOptions(): string[] {
  const options = ["-o", "BatchMode=yes", "-o", "ConnectTimeout=15"];
  const config = Deno.env.get("E2E_SSH_CONFIG");
  if (config !== undefined && config !== "") options.unshift("-F", config);
  return options;
}

async function run(command: string, args: string[], signal?: AbortSignal): Promise<void> {
  const process = new Deno.Command(command, {
    args,
    stdin: "null",
    stdout: "inherit",
    stderr: "inherit",
  }).spawn();
  const status = await waitForCommand(process, process.status, signal);
  if (!status.success) throw new Error(`${command} failed with exit code ${status.code}`);
}

async function output(command: string, args: string[], signal?: AbortSignal): Promise<string> {
  const process = new Deno.Command(command, {
    args,
    stdin: "null",
    stdout: "piped",
    stderr: "inherit",
  }).spawn();
  const result = await waitForCommand(process, process.output(), signal);
  if (!result.success) throw new Error(`${command} failed with exit code ${result.code}`);
  return new TextDecoder().decode(result.stdout);
}

async function sha256(path: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", await Deno.readFile(path));
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

function assertRecipient(value: string): void {
  if (!/^age1[0-9a-z]{58}$/.test(value)) throw new Error("invalid age recipient");
}

function assertSshHost(value: string): void {
  if (!/^(?:[A-Za-z0-9][A-Za-z0-9._-]*@)?[A-Za-z0-9][A-Za-z0-9._-]*$/.test(value)) {
    throw new Error("E2E_MAC_HOST must be an SSH host or user@host");
  }
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
