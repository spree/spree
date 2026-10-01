import fs from 'node:fs'
import path from 'node:path'
// Explicit .js extensions: this entry ships compiled (dist/vite), where the
// specifiers must name the real emitted files. Bundlers map .js back to .ts.
import { discoverDashboardPluginManifests } from './discover.js'
import { assertNoRouteCollisions, type RouteSource } from './route-collisions.js'

export interface RouteMountOptions {
  /** Host project root — where its `package.json` and own routes live. */
  hostRoot: string
  /** The panel's own routes: its package name and resolved routes directory. */
  shell: RouteSource
  /**
   * Which panel the tree is for. Picks the plugin marker key: `routes` for
   * the operator's dashboard, `sellerRoutes` for the seller panel.
   */
  panel: 'dashboard' | 'seller'
  /** Explicit plugin whitelist; omitted means auto-discovery from host deps. */
  plugins?: string[]
  /**
   * The host app's own routes directory, relative to `hostRoot`. Mounted when
   * it exists; `false` turns it off.
   */
  hostRoutes?: string | false
  onWarn?: (message: string) => void
}

/**
 * The route directories a panel composes next to its own pages: every
 * discovered plugin's routes for this panel, then the host app's own.
 *
 * Fails the build on a route path claimed by two sources, naming the
 * packages, before the TanStack generator's file-path-only error would fire.
 *
 * @returns directories relative to the shell's routes directory, with forward
 *   slashes, ready for `physical('', dir)`
 */
export function resolveRouteMounts(options: RouteMountOptions): string[] {
  const { hostRoot, shell, panel } = options

  const manifests = discoverDashboardPluginManifests(
    { root: hostRoot, onWarn: options.onWarn },
    options.plugins,
  )
  const sources: RouteSource[] = manifests.flatMap((manifest) => {
    const routesDir = panel === 'seller' ? manifest.sellerRoutesDir : manifest.routesDir
    return routesDir ? [{ label: manifest.name, routesDir }] : []
  })

  const hostSource = hostRouteSource(hostRoot, shell.routesDir, options.hostRoutes ?? 'src/routes')
  if (hostSource) sources.push(hostSource)

  assertNoRouteCollisions([shell, ...sources])

  // The generator expects forward slashes; path.relative emits backslashes on Windows.
  return sources.map((source) =>
    path.relative(shell.routesDir, source.routesDir).split(path.sep).join('/'),
  )
}

function hostRouteSource(
  hostRoot: string,
  shellRoutesDir: string,
  hostRoutes: string | false,
): RouteSource | undefined {
  if (hostRoutes === false) return undefined
  const routesDir = path.resolve(hostRoot, hostRoutes)
  if (!isDirectory(routesDir)) return undefined
  // The shell building itself has its own pages at `src/routes`, already mounted.
  if (fs.realpathSync(routesDir) === fs.realpathSync(shellRoutesDir)) return undefined
  return { label: hostLabel(hostRoot), routesDir }
}

function hostLabel(hostRoot: string): string {
  try {
    const { name } = JSON.parse(fs.readFileSync(path.join(hostRoot, 'package.json'), 'utf8'))
    if (typeof name === 'string' && name) return `${name} (your app)`
  } catch {}
  return 'your app'
}

function isDirectory(dir: string): boolean {
  try {
    return fs.statSync(dir).isDirectory()
  } catch {
    return false
  }
}
