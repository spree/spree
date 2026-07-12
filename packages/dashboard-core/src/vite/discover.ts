import fs from 'node:fs'
import { createRequire } from 'node:module'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

/**
 * Walk a host project's `package.json` dependencies and return the names of
 * packages that opt-in as dashboard plugins by declaring
 * `"spree": { "dashboard": { "plugin": true } }` in their own `package.json`.
 *
 * Auto-discovery is what makes `pnpm add @acme/foo-plugin` a one-step
 * install: the discovered list feeds both Tailwind source scanning and the
 * `virtual:spree-dashboard-plugins` activation module the app entry imports
 * (see index.ts). Plugin authors opt-in by adding the marker field; hosts
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

/** A discovered plugin plus the build-relevant fields from its marker. */
export interface DashboardPluginManifest {
  /** Package name, as it appears in the host's dependencies. */
  name: string
  /**
   * Absolute path to the plugin's file-routes directory, when the marker
   * declares one (`"spree": { "dashboard": { "routes": "./src/routes" } }`).
   * Compiled into the host's route tree by `@spree/dashboard/vite`.
   */
  routesDir?: string
}

/**
 * Like {@link discoverDashboardPlugins}, but returns each plugin's manifest
 * fields. `names` restricts resolution to an explicit whitelist (the
 * `plugins:` option) instead of walking the host's dependencies.
 */
export function discoverDashboardPluginManifests(
  { root, onWarn }: DiscoverOptions,
  names?: string[],
): DashboardPluginManifest[] {
  const require = createRequire(path.join(root, 'package.json'))
  const candidates = names ?? discoverDashboardPlugins({ root, onWarn })

  const manifests: DashboardPluginManifest[] = []
  for (const name of candidates) {
    const manifestPath = resolveManifest(name, require)
    if (!manifestPath) {
      manifests.push({ name })
      continue
    }
    let pkg: PluginManifest
    try {
      pkg = JSON.parse(fs.readFileSync(manifestPath, 'utf8')) as PluginManifest
    } catch (err) {
      onWarn?.(`Could not parse ${manifestPath}: ${(err as Error).message}`)
      manifests.push({ name })
      continue
    }
    const routes = pkg.spree?.dashboard?.routes
    manifests.push({
      name,
      routesDir: routes ? path.resolve(path.dirname(manifestPath), routes) : undefined,
    })
  }
  return manifests
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
      routes?: string
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

  let current = path.dirname(entry.startsWith('file:') ? fileURLToPath(entry) : entry)
  const { root } = path.parse(current)
  while (current !== root) {
    const candidate = path.join(current, 'package.json')
    if (fs.existsSync(candidate)) return candidate
    current = path.dirname(current)
  }
  return null
}
