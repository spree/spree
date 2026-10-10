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
  // Cast because the shell's root route requires no router context, which
  // TypeScript cannot prove through the generic tree parameter. The return
  // type stays parameterized by TRouteTree — that's what makes links typed.
  const options = {
    routeTree: withRootPluginRoutes(routeTree),
    basepath,
  } as RouterConstructorOptions<TRouteTree, 'never', false, RouterHistory, Record<string, unknown>>
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

/** Route options are a union of path and pathless shapes; both fields are optional here. */
type RouteOptionsLike = { id?: string; path?: string }

/**
 * Registry routes scoped `public` or `authenticated` live at the root, where
 * the store's `$storeId` param would otherwise claim every URL — so instead of
 * a catch-all they become real routes: public ones next to the login page,
 * authenticated ones inside the auth guard, beside the store selection page.
 *
 * The generated tree is shared by every router built from it, so it is never
 * changed. The router gets views of the root and `_authenticated` routes that
 * differ only in their children; every other read and write reaches the
 * generated route.
 */
function withRootPluginRoutes<TRouteTree extends AnyRoute>(routeTree: TRouteTree): TRouteTree {
  const entries = getPluginRoutes().filter(
    (entry): entry is RootRouteEntry => entry.scope === 'public' || entry.scope === 'authenticated',
  )
  if (entries.length === 0) return routeTree

  const rootChildren = routeTree.children as AnyRoute[]
  const authenticatedLayout = rootChildren.find(
    (route) => (route.options as RouteOptionsLike).id === '/_authenticated',
  )
  if (!authenticatedLayout) {
    throw new Error("Plugin routes outside a store need the dashboard's `_authenticated` route.")
  }

  const taken = new Set(routePaths(routeTree, '').map(comparablePath))
  const added: Record<RootRouteEntry['scope'], AnyRoute[]> = { public: [], authenticated: [] }
  for (const entry of entries) {
    if (taken.has(comparablePath(entry.path))) {
      throw new Error(
        `Plugin route "${entry.key}" path "${entry.path}" is already used by another dashboard page.`,
      )
    }
    taken.add(comparablePath(entry.path))

    const parent = entry.scope === 'public' ? routeTree : authenticatedLayout
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
    added[entry.scope].push(route)
  }

  const authenticatedView = withChildren(authenticatedLayout, [
    ...(authenticatedLayout.children as AnyRoute[]),
    ...added.authenticated,
  ])
  return withChildren(routeTree, [
    ...rootChildren.map((route) => (route === authenticatedLayout ? authenticatedView : route)),
    ...added.public,
  ])
}

function withChildren<TRoute extends AnyRoute>(route: TRoute, children: AnyRoute[]): TRoute {
  return new Proxy(route, {
    get: (target, property) => (property === 'children' ? children : Reflect.get(target, property)),
  })
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
