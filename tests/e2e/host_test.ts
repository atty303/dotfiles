import { strict as assert } from "node:assert";
import { hostE2eTarget } from "./host.ts";

Deno.test("host E2E dispatch selects the native environment", () => {
  assert.equal(hostE2eTarget("linux"), "linux");
  assert.equal(hostE2eTarget("darwin"), "macos");
  assert.throws(() => hostE2eTarget("windows"), /not implemented for windows/);
});
