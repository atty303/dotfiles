import { DatabaseSync } from "node:sqlite";

type Spec = {
  managed_paths: string[];
  null_paths: string[];
  excluded_paths: string[];
};

type Result = {
  status: string;
  managed?: Record<string, unknown>;
  managed_nulls?: string[];
  missing?: string[];
  unreviewed?: Record<string, string>;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return value !== null && typeof value === "object" && !Array.isArray(value);
}

function getPath(root: Record<string, unknown>, path: string) {
  let value: unknown = root;
  for (const part of path.split(".")) {
    if (!isRecord(value) || !Object.hasOwn(value, part)) {
      return { found: false, value: undefined };
    }
    value = value[part];
  }
  return { found: true, value };
}

function isCovered(path: string, knownPaths: string[]) {
  return knownPaths.some((known) => path === known || path.startsWith(`${known}.`));
}

function valueType(value: unknown) {
  if (value === null) return "null";
  if (Array.isArray(value)) return "array";
  if (isRecord(value)) return "object";
  return typeof value;
}

function classifyDatabaseError(error: unknown) {
  const message = error instanceof Error ? error.message.toLowerCase() : "";
  if (message.includes("no such table")) return "schema_unsupported";
  if (message.includes("locked") || message.includes("busy")) return "database_busy";
  if (message.includes("not a database") || message.includes("malformed")) return "database_invalid";
  return "database_unreadable";
}

async function readSpec(): Promise<Spec> {
  const text = await new Response(Deno.stdin.readable).text();
  const value: unknown = JSON.parse(text);
  if (!isRecord(value)) throw new Error("invalid_spec");
  if (
    !Array.isArray(value.managed_paths) ||
    !Array.isArray(value.null_paths) ||
    !Array.isArray(value.excluded_paths)
  ) {
    throw new Error("invalid_spec");
  }
  return value as Spec;
}

function projectSettings(settings: Record<string, unknown>, spec: Spec): Result {
  const managed: Record<string, unknown> = {};
  const managedNulls: string[] = [];
  const missing: string[] = [];
  const managedPaths = [...new Set([...spec.managed_paths, ...spec.null_paths])].sort();

  for (const path of managedPaths) {
    const result = getPath(settings, path);
    if (!result.found) {
      missing.push(path);
    } else if (result.value === null) {
      managedNulls.push(path);
    } else {
      managed[path] = result.value;
    }
  }

  const knownPaths = [...spec.managed_paths, ...spec.null_paths, ...spec.excluded_paths];
  const unreviewed: Record<string, string> = {};
  const visit = (value: unknown, prefix: string) => {
    if (isRecord(value)) {
      const keys = Object.keys(value).sort();
      if (keys.length === 0 && prefix && !isCovered(prefix, knownPaths)) {
        unreviewed[prefix] = "object";
      }
      for (const key of keys) {
        visit(value[key], prefix ? `${prefix}.${key}` : key);
      }
    } else if (prefix && !isCovered(prefix, knownPaths)) {
      unreviewed[prefix] = valueType(value);
    }
  };
  visit(settings, "");

  return {
    status: "ok",
    managed,
    managed_nulls: managedNulls.sort(),
    missing: missing.sort(),
    unreviewed,
  };
}

async function main() {
  const spec = await readSpec();
  const databasePath = Deno.args[0];
  let database: DatabaseSync | undefined;
  try {
    database = new DatabaseSync(databasePath, { readOnly: true, timeout: 1000 });
    const row = database.prepare(
      "SELECT payload FROM profile_state_documents WHERE domain = ?",
    ).get("settings") as { payload?: unknown } | undefined;
    if (!row) {
      console.log(JSON.stringify({ status: "settings_domain_missing" }));
      return;
    }
    if (typeof row.payload !== "string") {
      console.log(JSON.stringify({ status: "settings_payload_invalid" }));
      return;
    }
    let settings: unknown;
    try {
      settings = JSON.parse(row.payload);
    } catch {
      console.log(JSON.stringify({ status: "settings_payload_invalid" }));
      return;
    }
    if (!isRecord(settings)) {
      console.log(JSON.stringify({ status: "settings_payload_invalid" }));
      return;
    }
    console.log(JSON.stringify(projectSettings(settings, spec)));
  } catch (error) {
    console.log(JSON.stringify({ status: classifyDatabaseError(error) }));
  } finally {
    database?.close();
  }
}

await main();
