export const MAC_E2E = {
  cpuCount: 6,
  minimumAvailableDiskBytes: 55_000_000_000,
  image:
    "ghcr.io/cirruslabs/macos-tahoe-base@sha256:1214590cd279a1ff82897d802624362ced1ff960d7b9f99a6ced5bbf8071e319",
  memoryMiB: 10 * 1024,
} as const;
