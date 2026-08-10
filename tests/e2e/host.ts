export type HostE2eTarget = "linux" | "macos";

export function hostE2eTarget(os: typeof Deno.build.os): HostE2eTarget {
  switch (os) {
    case "linux":
      return "linux";
    case "darwin":
      return "macos";
    default:
      throw new Error(`Full E2E tests are not implemented for ${os}`);
  }
}

export async function runHostE2e(): Promise<void> {
  switch (hostE2eTarget(Deno.build.os)) {
    case "linux": {
      const { runLinuxTargets } = await import("./linux.ts");
      await runLinuxTargets();
      break;
    }
    case "macos": {
      const { runMacLocal } = await import("./mac.ts");
      await runMacLocal();
      break;
    }
  }
}
