#!/usr/bin/env -S deno run --allow-read

import { dirname, isAbsolute, join, normalize, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

export type GraphIssue = {
  file: string;
  target: string;
  kind: "missing" | "outside" | "self-cycle" | "cycle";
};

async function markdownFiles(root: string): Promise<string[]> {
  const files: string[] = [];
  async function visit(directory: string): Promise<void> {
    for await (const entry of Deno.readDir(directory)) {
      const path = join(directory, entry.name);
      if (entry.isDirectory) await visit(path);
      else if (entry.isFile && entry.name.endsWith(".md")) files.push(path);
    }
  }
  await visit(root);
  return files.sort();
}

function localTargets(markdown: string): string[] {
  return [...markdown.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)]
    .map((match) => match[1].trim().replace(/^<|>$/g, "").split("#", 1)[0])
    .filter((target) => target.length > 0 && !/^[a-z][a-z0-9+.-]*:/i.test(target));
}

export async function validateReferenceGraph(rootInput: string): Promise<GraphIssue[]> {
  const root = resolve(rootInput);
  const realRoot = await Deno.realPath(root);
  const files = await markdownFiles(root);
  const fileNodes = await Promise.all(files.map((file) => Deno.realPath(file)));
  const fileSet = new Set(fileNodes);
  const graph = new Map<string, string[]>();
  const issues: GraphIssue[] = [];

  for (const file of files) {
    const fileNode = await Deno.realPath(file);
    const edges: string[] = [];
    const body = await Deno.readTextFile(file);
    for (const rawTarget of localTargets(body)) {
      const target = normalize(
        isAbsolute(rawTarget) ? rawTarget : resolve(dirname(file), rawTarget),
      );
      const displayFile = relative(root, file);
      const lexicalRelative = relative(root, target);
      if (
        lexicalRelative === ".." || lexicalRelative.startsWith(`..${sep}`) ||
        isAbsolute(lexicalRelative)
      ) {
        issues.push({ file: displayFile, target: rawTarget, kind: "outside" });
        continue;
      }
      try {
        const stat = await Deno.stat(target);
        if (!stat.isFile) throw new Deno.errors.NotFound();
      } catch {
        issues.push({ file: displayFile, target: rawTarget, kind: "missing" });
        continue;
      }
      const realTarget = await Deno.realPath(target);
      const realRelative = relative(realRoot, realTarget);
      if (
        realRelative === ".." || realRelative.startsWith(`..${sep}`) || isAbsolute(realRelative)
      ) {
        issues.push({ file: displayFile, target: rawTarget, kind: "outside" });
        continue;
      }
      if (realTarget === fileNode) {
        issues.push({ file: displayFile, target: rawTarget, kind: "self-cycle" });
      } else if (fileSet.has(realTarget)) {
        edges.push(realTarget);
      }
    }
    graph.set(fileNode, edges);
  }

  const state = new Map<string, 0 | 1 | 2>();
  const stack: string[] = [];
  const reported = new Set<string>();
  function visit(node: string): void {
    state.set(node, 1);
    stack.push(node);
    for (const next of graph.get(node) ?? []) {
      if (state.get(next) === 1) {
        const start = stack.indexOf(next);
        const cycle = [...stack.slice(start), next].map((path) => relative(realRoot, path));
        const key = cycle.slice(0, -1).sort().join("|");
        if (!reported.has(key)) {
          reported.add(key);
          issues.push({
            file: relative(realRoot, node),
            target: cycle.join(" -> "),
            kind: "cycle",
          });
        }
      } else if (!state.has(next)) visit(next);
    }
    stack.pop();
    state.set(node, 2);
  }
  for (const file of fileNodes) if (!state.has(file)) visit(file);
  return issues;
}

if (import.meta.main) {
  const root = Deno.args[0] ?? resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
  const issues = await validateReferenceGraph(root);
  if (issues.length > 0) {
    for (const issue of issues) console.error(`${issue.kind}: ${issue.file}: ${issue.target}`);
    Deno.exit(1);
  }
  console.log(`valid reference graph: ${root}`);
}
