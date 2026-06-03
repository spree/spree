import fs from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'

/**
 * Walk a host project's `package.json` dependencies and return the names of
 * packages that opt-in as dashboard plugins by declaring
 * `"spree": { "dashboard": { "plugin": true } }` in their own `package.json`.
 *
 * Auto-discovery is what makes `pnpm add @acme/foo-plugin` a one-step install
 * for host-app developers — no manual edit of `vite.config.ts` to register
 * the plugin name. Plugin authors opt-in by adding the marker field; hosts
 * never have to know it exists.
 *
 * Order is deterministic — the order packages appear in the host's combined
 * `dependencies` + `devDependencies` maps. Tailwind class scanning is
 * order-insensitive, so this only matters for the dev-mode banner's listing.
 *
 * The function does not throw on missing files or malformed JSON — failures
 * are reported via the `onWarn` callback and the offending package is
 * skipped. A missing host `package.json` returns an empty array.
 */
export interface DiscoverOptions {
  /** Project root to scan. Usually Vite's `config.root`. */
  root: string
  /** Optional callback for per-package warnings (malformed JSON, missing dep). */
  onWarn?: (message: string) => void
}

export function discoverDashboardPlugins({ root, onWarn }: DiscoverOptions): string[] {
  const hostPkgPath = path.join(root, 'package.json')
  if (!fs.existsSync(hostPkgPath)) return []

  let hostPkg: HostManifest
  try {
    hostPkg = JSON.parse(fs.readFileSync(hostPkgPath, 'utf8')) as HostManifest
  } catch (err) {
    onWarn?.(`Could not parse ${hostPkgPath}: ${(err as Error).message}`)
    return []
  }

  const deps = [
    ...Object.keys(hostPkg.dependencies ?? {}),
    ...Object.keys(hostPkg.devDependencies ?? {}),
  ]

  // Resolve from the host's own root so workspace symlinks and `pnpm`'s
  // `.pnpm/` hoisting both work. createRequire wants a file path, not a
  // directory, so synthesize one.
  const require = createRequire(path.join(root, 'package.json'))

  const discovered: string[] = []
  const seen = new Set<string>()

  for (const name of deps) {
    if (seen.has(name)) continue
    seen.add(name)

    const manifestPath = resolveManifest(name, require)
    if (!manifestPath) continue

    let depPkg: PluginManifest
    try {
      depPkg = JSON.parse(fs.readFileSync(manifestPath, 'utf8')) as PluginManifest
    } catch (err) {
      onWarn?.(`Could not parse ${manifestPath}: ${(err as Error).message}`)
      continue
    }

    if (depPkg.spree?.dashboard?.plugin === true) {
      discovered.push(name)
    }
  }

  return discovered
}

interface HostManifest {
  dependencies?: Record<string, string>
  devDependencies?: Record<string, string>
}

interface PluginManifest {
  spree?: {
    dashboard?: {
      plugin?: boolean
    }
  }
}

/**
 * Resolve `<pkg>/package.json` to its filesystem path. We can't always do
 * `require.resolve('<pkg>/package.json')` because many packages don't expose
 * it in their `exports` map. Fall back to walking up from the resolved entry
 * point — same pattern as the source-dir resolver in `index.ts`.
 */
function resolveManifest(pkg: string, require: NodeJS.Require): string | null {
  try {
    return require.resolve(`${pkg}/package.json`)
  } catch {
    // exports map didn't include package.json; walk up from the main entry.
  }

  let entry: string
  try {
    entry = require.resolve(pkg)
  } catch {
    return null
  }

  let current = path.dirname(entry.startsWith('file:') ? entry.slice(7) : entry)
  const { root } = path.parse(current)
  while (current !== root) {
    const candidate = path.join(current, 'package.json')
    if (fs.existsSync(candidate)) return candidate
    current = path.dirname(current)
  }
  return null
}
