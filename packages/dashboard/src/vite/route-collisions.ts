import fs from 'node:fs'
import path from 'node:path'

/**
 * A source of route files being composed into the tree — either the shell or
 * a plugin. `label` is what a collision message names (a package name), so
 * authors see "@acme/reviews" rather than a deep node_modules path.
 */
export interface RouteSource {
  label: string
  routesDir: string
}

interface DeclaredRoute {
  /** The composed path from the file's `createFileRoute('…')` literal. */
  routePath: string
  file: string
  source: string
}

// Matches the first `createFileRoute('…')` / `createFileRoute("…")` literal.
// The generator treats this literal as authoritative for the route path, so
// pre-flighting on it detects exactly the conflicts the generator would.
const CREATE_FILE_ROUTE = /createFileRoute\(\s*(['"])([^'"]+)\1/
const ROUTE_FILE_EXT = new Set(['.tsx', '.ts', '.jsx', '.js'])

/**
 * Detect route-path collisions across the shell and every plugin *before*
 * the TanStack generator runs, and throw an error that names the conflicting
 * **packages** and path. Without this, a duplicate route surfaces as the
 * generator's file-path-only error, which plugin authors must map back to
 * packages by hand.
 *
 * Only flags cross-source collisions (two different packages claiming the
 * same path). Duplicates *within* one source are the generator's to report —
 * they're an authoring bug in a single package, and the file-level message is
 * already actionable there.
 *
 * @throws Error naming the conflicting sources and path.
 */
export function assertNoRouteCollisions(sources: RouteSource[]): void {
  const byPath = new Map<string, DeclaredRoute[]>()

  for (const source of sources) {
    const seenInSource = new Set<string>()
    for (const { routePath, file } of readDeclaredRoutes(source.routesDir)) {
      // Collapse within-source duplicates to a single entry so we only report
      // cross-source conflicts here.
      if (seenInSource.has(routePath)) continue
      seenInSource.add(routePath)
      const list = byPath.get(routePath) ?? []
      list.push({ routePath, file, source: source.label })
      byPath.set(routePath, list)
    }
  }

  const conflicts = [...byPath.values()].filter((list) => list.length > 1)
  if (conflicts.length === 0) return

  const details = conflicts
    .map((list) => {
      const path = list[0].routePath
      const sources = list.map((r) => `  - ${r.source} (${r.file})`).join('\n')
      return `Route "${path}" is declared by more than one package:\n${sources}`
    })
    .join('\n\n')

  throw new Error(
    `Dashboard route collision.\n\n${details}\n\n` +
      'Two packages cannot own the same route path. Rename one route, or ' +
      "remove the plugin that shouldn't own it.",
  )
}

/** Extract the `createFileRoute` literal from every route file under `dir`. */
function readDeclaredRoutes(dir: string): Array<{ routePath: string; file: string }> {
  if (!dirExists(dir)) return []
  const out: Array<{ routePath: string; file: string }> = []
  for (const file of walkFiles(dir)) {
    if (!ROUTE_FILE_EXT.has(path.extname(file))) continue
    let contents: string
    try {
      contents = fs.readFileSync(file, 'utf8')
    } catch {
      continue
    }
    const match = CREATE_FILE_ROUTE.exec(contents)
    if (match) out.push({ routePath: match[2], file })
  }
  return out
}

function dirExists(dir: string): boolean {
  try {
    return fs.statSync(dir).isDirectory()
  } catch {
    return false
  }
}

function* walkFiles(dir: string): Generator<string> {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name)
    if (entry.isDirectory()) {
      yield* walkFiles(full)
    } else if (entry.isFile()) {
      yield full
    }
  }
}
