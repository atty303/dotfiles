import { $ } from "@david/dax";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

export interface StagedSource {
  archivePath: string;
  identity: string;
  identityPath: string;
  sha256: string;
  tempDir: string;
}

const SENTINEL = "chezmoi-e2e-sentinel\n";

export function repositoryRoot(): string {
  return join(dirname(fileURLToPath(import.meta.url)), "..", "..");
}

export async function stageSource(signal: AbortSignal): Promise<StagedSource> {
  return await stageRepository(repositoryRoot(), signal);
}

export async function stageRepository(
  repository: string,
  signal: AbortSignal,
): Promise<StagedSource> {
  const tempDir = await Deno.makeTempDir({ prefix: "chezmoi-e2e-" });

  try {
    const stagedRepository = join(tempDir, "source");
    const initialArchive = join(tempDir, "worktree.tar");
    const archivePath = join(tempDir, "source.tar");
    const identityPath = join(tempDir, "identity.txt");
    const plaintextPath = join(tempDir, "sentinel.txt");
    const encryptedPath = join(
      stagedRepository,
      "home",
      "dot_config",
      "chezmoi-e2e",
      "encrypted_private_sentinel.txt.age",
    );

    await $`tar --exclude=.git --exclude=key.txt.age --exclude=${"*.age"} -cf ${initialArchive} -C ${repository} .`
      .signal(signal);
    await Deno.mkdir(stagedRepository, { recursive: true });
    await $`tar -xf ${initialArchive} -C ${stagedRepository}`.signal(signal);

    await $`age-keygen -o ${identityPath}`.stderr("null").signal(signal);
    await Deno.chmod(identityPath, 0o600);
    const recipient = await $`age-keygen -y ${identityPath}`.signal(signal).text();
    const identity = await Deno.readTextFile(identityPath);

    await Deno.mkdir(dirname(encryptedPath), { recursive: true });
    await Deno.writeTextFile(plaintextPath, SENTINEL, { mode: 0o600 });
    await $`age --recipient ${recipient} --output ${encryptedPath} ${plaintextPath}`.signal(signal);
    await Deno.remove(plaintextPath);
    await Deno.remove(initialArchive);

    await $`tar -cf ${archivePath} -C ${stagedRepository} .`.signal(signal);
    const digest = await crypto.subtle.digest("SHA-256", await Deno.readFile(archivePath));
    const sha256 = Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0"))
      .join("");

    return { archivePath, identity, identityPath, sha256, tempDir };
  } catch (error) {
    await Deno.remove(tempDir, { recursive: true }).catch(() => undefined);
    throw error;
  }
}
