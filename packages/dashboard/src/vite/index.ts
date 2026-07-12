/* Vite integration for hosts building on the full `@spree/dashboard` shell.
 *
 * Extends `@spree/dashboard-core/vite` (Tailwind wiring, plugin discovery,
 * the `virtual:spree-dashboard-plugins` activation module) with route-tree
 * composition: the TanStack Router generator runs in the HOST build over a
 * virtual route config that mounts the shell's route files plus every
 * discovered plugin's file-routes directory. The composed `routeTree.gen.ts`
 * lands in the host (default `src/routeTree.gen.ts`), so typed links cover
 * shell, host, and plugin routes in one program — and regenerate from the
 * installed package versions on every dev start and build.
 *
 * Custom dashboards built directly on `dashboard-core` + `dashboard-ui`
 * should import `@spree/dashboard-core/vite` instead — no shell, no shell
 * routes to compose.
 */
import { createRequire } from 'node:module'
import path from 'node:path'
// Self-referencing package import (not a relative path): Node loads this
// module raw when a host's vite.config.ts imports `@spree/dashboard/vite`,
// and TS type-stripping can't resolve extensionless relative specifiers.
import { assertNoRouteCollisions, type RouteSource } from '@spree/dashboard/vite/route-collisions'
import {
  type SpreeDashboardPluginOptions as CoreOptions,
  spreeDashboardPlugin as spreeDashboardCorePlugin,
} from '@spree/dashboard-core/vite'
import { discoverDashboardPluginManifests } from '@spree/dashboard-core/vite/discover'
import { TanStackRouterVite } from '@tanstack/router-plugin/vite'
import { index, layout, physical, rootRoute, route } from '@tanstack/virtual-file-routes'
import type { PluginOption } from 'vite'

export interface SpreeDashboardPluginOptions extends CoreOptions {
  /**
   * Where the composed route tree is generated, relative to the host root.
   * Commit this file: it regenerates on every dev start/build, and its diff
   * on a `@spree/dashboard` (or plugin) upgrade shows exactly which admin
   * pages the upgrade added or moved.
   */
  generatedRouteTree?: string
  /**
   * Host project root. Defaults to `process.cwd()` — correct when Vite runs
   * from the package directory, which is how the starter and every
   * create-spree-app project operate. Pass explicitly when running Vite
   * with a different `root`.
   */
  root?: string
}

export function spreeDashboardPlugin(options: SpreeDashboardPluginOptions = {}): PluginOption[] {
  const hostRoot = options.root ?? process.cwd()
  return [...spreeDashboardCorePlugin(options), dashboardRouterPlugin(hostRoot, options)]
}

/**
 * The TanStack Router generator, configured with a virtual route config that
 * mirrors the shell's top-level layout skeleton and physically mounts:
 *
 *   - the shell's `_authenticated/$storeId` pages, and
 *   - each plugin's declared routes directory (the `spree.dashboard.routes`
 *     marker), under the same authenticated store scope.
 *
 * The skeleton names the shell's top-level route files explicitly; when the
 * shell grows a new top-level route it must be added here. The shell's own
 * Vite config uses this same composition, so a missed file breaks the
 * shell's dev/e2e in-repo rather than silently in hosts.
 */
function dashboardRouterPlugin(hostRoot: string, options: SpreeDashboardPluginOptions) {
  const fromHost = createRequire(path.join(hostRoot, 'package.json'))
  // Resolve the shell's routes directory from wherever the host's
  // `@spree/dashboard` lives (workspace symlink or npm install). The `.`
  // export maps to a file in src/, so `routes/` is its sibling directory.
  const shellEntry = fromHost.resolve('@spree/dashboard')
  const shellRoutesDir = path.join(path.dirname(shellEntry), 'routes')

  const manifests = discoverDashboardPluginManifests(
    { root: hostRoot, onWarn: (msg) => console.warn(`[@spree/dashboard/vite] ${msg}`) },
    options.plugins,
  )
  const routedPlugins = manifests.filter((m): m is typeof m & { routesDir: string } =>
    Boolean(m.routesDir),
  )

  // Pre-flight: fail on route-path collisions with an error naming the
  // offending packages (the shell counts as `@spree/dashboard`), before the
  // generator's file-path-only error would fire.
  const sources: RouteSource[] = [
    { label: '@spree/dashboard', routesDir: shellRoutesDir },
    ...routedPlugins.map((m) => ({ label: m.name, routesDir: m.routesDir })),
  ]
  assertNoRouteCollisions(sources)

  const pluginMounts = routedPlugins.map((m) =>
    physical('', path.relative(shellRoutesDir, m.routesDir)),
  )

  const virtualRouteConfig = rootRoute('__root.tsx', [
    route('/login', 'login.tsx'),
    route('/forgot-password', 'forgot-password.tsx'),
    route('/reset-password', 'reset-password.tsx'),
    route('/accept-invitation/$invitationId', 'accept-invitation.$invitationId.tsx'),
    layout('_authenticated.tsx', [
      index('_authenticated/index.tsx'),
      route('/$storeId', '_authenticated/$storeId.tsx', [
        physical('', '_authenticated/$storeId'),
        ...pluginMounts,
      ]),
    ]),
  ])

  return TanStackRouterVite({
    target: 'react',
    virtualRouteConfig,
    routesDirectory: shellRoutesDir,
    generatedRouteTree: path.resolve(
      hostRoot,
      options.generatedRouteTree ?? 'src/routeTree.gen.ts',
    ),
  })
}
