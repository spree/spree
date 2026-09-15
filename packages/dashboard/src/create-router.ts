import { ErrorState } from '@spree/dashboard-ui'
import {
  type AnyRoute,
  createRouter,
  type RouterConstructorOptions,
  type RouterHistory,
} from '@tanstack/react-router'
import { createElement } from 'react'
import { RoutePending } from './components/spree/route-pending'

/**
 * Build the dashboard's router from a generated route tree.
 *
 * Hosts generate their own `routeTree.gen.ts` (via `@spree/dashboard/vite`,
 * which composes the shell's routes with every installed plugin's file
 * routes) and register the resulting router for typed links:
 *
 *     import { routeTree } from './routeTree.gen'
 *
 *     const router = createDashboardRouter(routeTree)
 *
 *     declare module '@tanstack/react-router' {
 *       interface Register {
 *         router: typeof router
 *       }
 *     }
 *
 * The `Register` augmentation lives in HOST code on purpose: interface
 * augmentations merge program-wide, so the shell declaring its own would
 * conflict with the host's composed tree.
 */
export interface DashboardRouterOptions {
  /**
   * Path prefix when the dashboard is served from a sub-path (the single-node
   * topology mounts it at `/dashboard`). Pass `import.meta.env.BASE_URL` so it
   * always matches the Vite `base` the app was built with.
   */
  basepath?: string
}

export function createDashboardRouter<TRouteTree extends AnyRoute>(
  routeTree: TRouteTree,
  { basepath }: DashboardRouterOptions = {},
) {
  // Cast because the shell's root route requires no router context, which
  // TypeScript cannot prove through the generic tree parameter. The return
  // type stays parameterized by TRouteTree — that's what makes links typed.
  const options = { routeTree, basepath } as RouterConstructorOptions<
    TRouteTree,
    'never',
    false,
    RouterHistory,
    Record<string, unknown>
  >
  return createRouter({
    ...options,
    // Every route inherits this while its chunk or loader resolves. Without it
    // TanStack renders a bare "Loading…" string on an otherwise blank page.
    defaultPendingComponent: RoutePending,
    // Without this a thrown render or loader error takes the whole admin down
    // to a white screen. TanStack hands the component `{ error, reset }`, so
    // the merchant gets the message and a retry rather than a dead tab.
    // `createElement` rather than JSX so this stays a `.ts` module: renaming
    // it to `.tsx` changes the specifier every importer resolves, which a
    // running dev server caches and then fails to find.
    defaultErrorComponent: ({ error, reset }) =>
      createElement(ErrorState, { error, onRetry: reset }),
    // Long enough that a fast navigation never flashes a skeleton, short enough
    // that a slow one doesn't look frozen.
    defaultPendingMs: 300,
    defaultPendingMinMs: 400,
  })
}
