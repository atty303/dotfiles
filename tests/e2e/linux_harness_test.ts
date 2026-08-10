import { strict as assert } from "node:assert";
import {
  cleanupSuccessfulResources,
  type ResourceKind,
  type ResourcePresence,
  retainedResourceReport,
} from "./linux_cleanup.ts";
import { selectLinuxTargets } from "./linux.ts";

Deno.test("standard Linux targets cover CI environments without Bazzite", () => {
  assert.deepEqual(selectLinuxTargets(), ["fedora", "ubuntu-desktop", "ubuntu-headless"]);
  assert.deepEqual(selectLinuxTargets("bazzite"), ["bazzite"]);
});

Deno.test("successful cleanup removes the volume after the container", async () => {
  const calls: string[] = [];
  const presence: Record<ResourceKind, ResourcePresence> = {
    container: "present",
    volume: "present",
  };
  const result = await cleanupSuccessfulResources({
    presence: (kind) => {
      calls.push(`presence:${kind}`);
      return Promise.resolve(presence[kind]);
    },
    remove: (kind) => {
      calls.push(`remove:${kind}`);
      presence[kind] = "absent";
      return Promise.resolve(0);
    },
  });

  assert.deepEqual(result, {
    containerPresence: "absent",
    errors: [],
    volumePresence: "absent",
  });
  assert.deepEqual(calls, [
    "presence:container",
    "presence:volume",
    "remove:container",
    "presence:container",
    "remove:volume",
    "presence:volume",
  ]);
});

Deno.test("cleanup retains the volume when container removal fails", async () => {
  const removed: ResourceKind[] = [];
  const result = await cleanupSuccessfulResources({
    presence: (kind) => Promise.resolve(kind === "container" ? "present" : "unknown"),
    remove: (kind) => {
      removed.push(kind);
      return Promise.resolve(125);
    },
  });

  assert.deepEqual(removed, ["container"]);
  assert.deepEqual(result, {
    containerPresence: "present",
    errors: ["container cleanup exited 125"],
    volumePresence: "unknown",
  });
});

Deno.test("cleanup reports resources that remain after successful removal commands", async () => {
  const result = await cleanupSuccessfulResources({
    presence: () => Promise.resolve("present"),
    remove: () => Promise.resolve(0),
  });

  assert.deepEqual(result, {
    containerPresence: "present",
    errors: ["container cleanup left resource present"],
    volumePresence: "present",
  });
});

Deno.test("retained resource report reflects source preparation progress", () => {
  const base = {
    containerName: "container-name",
    containerPresence: "present" as const,
    home: "/home/e2e",
    logDirectory: "/logs/run",
    privilegedSystemd: false,
    user: "e2e",
    volumeName: "volume-name",
    volumePresence: "present" as const,
  };

  const beforeCopy = retainedResourceReport({
    ...base,
    archiveCopied: false,
    sourcePrepared: false,
  });
  assert.match(beforeCopy, /source archive: not copied/);
  assert.doesNotMatch(beforeCopy, /prepare source:/);

  const afterCopy = retainedResourceReport({
    ...base,
    archiveCopied: true,
    sourcePrepared: false,
  });
  assert.match(afterCopy, /prepare source:/);
  assert.match(afterCopy, /retry install after preparation:/);

  const afterPreparation = retainedResourceReport({
    ...base,
    archiveCopied: true,
    sourcePrepared: true,
  });
  assert.match(afterPreparation, /retry install:/);
  assert.doesNotMatch(afterPreparation, /prepare source:/);
  assert.match(afterPreparation, /remove container: podman rm --force container-name/);
  assert.match(afterPreparation, /remove volume: podman volume rm volume-name/);
});
