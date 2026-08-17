import { createRequire } from 'node:module'
import path from 'node:path'
import {
  type SpreeDashboardPluginOptions as CoreOptions,
  spreeDashboardPlugin as spreeDashboardCorePlugin,
} from '@spree/dashboard-core/vite'
import { TanStackRouterVite } from '@tanstack/router-plugin/vite'
import { index, layout, physical, rootRoute, route } from '@tanstack/virtual-file-routes'
import type { PluginOption } from 'vite'

export interface SpreeSellerDashboardPluginOptions extends CoreOptions {
  /**
   * Where the composed route tree is generated, relative to the host root.
   * Commit this file: it regenerates on every dev start/build, and its diff
   * on a `@spree/seller-dashboard` upgrade shows exactly which pages the
   * upgrade added or moved.
   */
  generatedRouteTree?: string
  /**
   * Host project root. Defaults to `process.cwd()` — correct when Vite runs
   * from the package directory, which is how the starter operates.
   */
  root?: string
}

/**
 * Vite integration for the seller panel.
 *
 * The Tailwind and plugin-discovery half comes from `@spree/dashboard-core`
 * unchanged — neither is admin-specific. Only the route skeleton differs,
 * because a seller's panel is scoped by seller where the operator's is scoped
 * by store.
 */
export function spreeSellerDashboardPlugin(
  options: SpreeSellerDashboardPluginOptions = {},
): PluginOption[] {
  const hostRoot = options.root ?? process.cwd()
  return [
    // Name this shell so Tailwind scans the panel's own components; core
    // defaults to the operator's dashboard, which a seller's host does not
    // install.
    ...spreeDashboardCorePlugin({
      shellPackages: ['@spree/seller-dashboard'],
      ...options,
    }),
    sellerRouterPlugin(hostRoot, options),
  ]
}

/**
 * The TanStack Router generator, configured with a virtual route config
 * mirroring the panel's layout skeleton: public sign-in, then an
 * authenticated branch whose pages all hang off a seller.
 */
function sellerRouterPlugin(hostRoot: string, options: SpreeSellerDashboardPluginOptions) {
  const fromHost = createRequire(path.join(hostRoot, 'package.json'))
  // Resolve the shell's routes directory from wherever the host's
  // `@spree/seller-dashboard` lives (workspace symlink or npm install). The
  // `.` export maps to a file in src/, so `routes/` is its sibling.
  const shellEntry = fromHost.resolve('@spree/seller-dashboard')
  const shellRoutesDir = path.join(path.dirname(shellEntry), 'routes')

  const virtualRouteConfig = rootRoute('__root.tsx', [
    route('/login', 'login.tsx'),
    route('/accept-invitation/$invitationId', 'accept-invitation.$invitationId.tsx'),
    layout('_authenticated.tsx', [
      index('_authenticated/index.tsx'),
      route('/$sellerId', '_authenticated/$sellerId.tsx', [
        physical('', '_authenticated/$sellerId'),
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
