import { getPluginRoutes, type RootRouteEntry } from '@spree/dashboard-core'
import { ErrorState } from '@spree/dashboard-ui'
import {
  type AnyRoute,
  createRoute,
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
  mountRootPluginRoutes(routeTree)
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

const mountedRootRoutes = new WeakSet<AnyRoute>()

/** Route options are a union of path and pathless shapes; both fields are optional here. */
type RouteOptionsLike = { id?: string; path?: string }

/**
 * Registry routes scoped `public` or `authenticated` live at the root, where
 * the store's `$storeId` param would otherwise claim every URL — so instead of
 * a catch-all they become real routes: public ones next to the login page,
 * authenticated ones inside the auth guard, beside the store picker. Building
 * the router twice from the same tree (tests, hot reload) replaces them rather
 * than mounting them twice.
 */
function mountRootPluginRoutes(routeTree: AnyRoute) {
  const authenticatedLayout = (routeTree.children as AnyRoute[] | undefined)?.find(
    (route) => (route.options as RouteOptionsLike).id === '/_authenticated',
  )
  if (!authenticatedLayout) return

  const parents = { public: routeTree, authenticated: authenticatedLayout }
  for (const parent of Object.values(parents)) {
    parent.addChildren(
      (parent.children as AnyRoute[]).filter((route) => !mountedRootRoutes.has(route)),
    )
  }

  const entries = getPluginRoutes().filter(
    (entry): entry is RootRouteEntry => entry.scope === 'public' || entry.scope === 'authenticated',
  )
  if (entries.length === 0) return

  const taken = new Set(routePaths(routeTree, '').map(comparablePath))
  for (const entry of entries) {
    if (taken.has(comparablePath(entry.path))) {
      throw new Error(
        `Plugin route "${entry.key}" path "${entry.path}" is already used by another dashboard page.`,
      )
    }
    taken.add(comparablePath(entry.path))

    const parent = parents[entry.scope]
    const route: AnyRoute = createRoute({
      getParentRoute: () => parent,
      path: entry.path,
      component: function PluginRootRoute() {
        return createElement(entry.component, {
          params: route.useParams() as Record<string, string>,
          searchParams: route.useSearch() as Record<string, unknown>,
        })
      },
    })
    mountedRootRoutes.add(route)
    parent.addChildren([...(parent.children as AnyRoute[]), route])
  }
}

/** Full URL path of every route below `route`, read from the route options. */
function routePaths(route: AnyRoute, parentPath: string): string[] {
  return ((route.children as AnyRoute[] | undefined) ?? []).flatMap((child) => {
    const ownPath = (child.options as RouteOptionsLike).path
    const fullPath = ownPath ? `${parentPath}/${ownPath}` : parentPath
    return ownPath ? [fullPath, ...routePaths(child, fullPath)] : routePaths(child, fullPath)
  })
}

/** `/a//b/` and `/a/b` reach the same page, as do `/a/$id` and `/a/$slug`. */
function comparablePath(path: string): string {
  return (
    path
      .replace(/\/{2,}/g, '/')
      .replace(/\/\$[^/]+/g, '/$')
      .replace(/\/$/, '') || '/'
  )
}
