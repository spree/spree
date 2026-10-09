import { __resetPluginRoutes, pluginRoutes } from '@spree/dashboard-core'
import { type AnyRoute, createRootRoute, createRoute } from '@tanstack/react-router'
import { afterEach, describe, expect, it } from 'vitest'
import { createDashboardRouter } from './create-router'

// The shell's top-level skeleton, built the way the generated tree builds it:
// a pathless `_authenticated` layout holding the store picker and the store.
function shellTree() {
  const root = createRootRoute()
  const authenticated = createRoute({ getParentRoute: () => root, id: '_authenticated' })
  ;(authenticated.options as { id: string }).id = '/_authenticated'
  const login = createRoute({ getParentRoute: () => root, path: '/login' })
  const storeSelection = createRoute({ getParentRoute: () => authenticated, path: '/' })
  const store = createRoute({ getParentRoute: () => authenticated, path: '$storeId' })
  return root.addChildren([login, authenticated.addChildren([storeSelection, store])])
}

const Page = () => null

function mountedRoutes(router: { routesById: unknown }) {
  const routes = Object.values(router.routesById as Record<string, AnyRoute>)
  return new Map(routes.map((route) => [route.fullPath as string, route]))
}

describe('createDashboardRouter', () => {
  afterEach(() => __resetPluginRoutes())

  it('mounts public registry routes at the root and signed-in ones inside the auth guard', () => {
    pluginRoutes.add({ key: 'sign-up', scope: 'public', path: '/sign-up', component: Page })
    pluginRoutes.add({ key: 'account', scope: 'authenticated', path: '/account', component: Page })
    pluginRoutes.add({ key: 'brands', path: '/brands', component: Page })

    const routes = mountedRoutes(createDashboardRouter(shellTree()))

    expect(routes.get('/sign-up')?.parentRoute.id).toBe('__root__')
    expect(routes.get('/account')?.parentRoute.id).toBe('/_authenticated')
    // Store routes keep going through the `$storeId` catch-all.
    expect(routes.has('/brands')).toBe(false)
  })

  it('matches a root registry route ahead of the store param', () => {
    pluginRoutes.add({ key: 'account', scope: 'authenticated', path: '/account', component: Page })

    const router = createDashboardRouter(shellTree())

    expect(router.getMatchedRoutes('/account')[2]?.fullPath).toBe('/account')
    expect(router.getMatchedRoutes('/store_1')[2]?.fullPath).toBe('/$storeId')
  })

  it('mounts each route once when the router is built twice from one tree', () => {
    pluginRoutes.add({ key: 'sign-up', scope: 'public', path: '/sign-up', component: Page })
    const tree = shellTree()

    createDashboardRouter(tree)
    const router = createDashboardRouter(tree)

    const ids = Object.values(router.routesById as Record<string, AnyRoute>).map((r) => r.id)
    expect(ids.filter((id) => id === '/sign-up')).toHaveLength(1)
  })

  it('refuses a root route that takes the path of a dashboard page', () => {
    pluginRoutes.add({ key: 'my-login', scope: 'public', path: '/login', component: Page })
    expect(() => createDashboardRouter(shellTree())).toThrow(
      'Plugin route "my-login" path "/login" is already used by another dashboard page.',
    )
  })

  it('refuses a root route that replaces the store selection page', () => {
    pluginRoutes.add({ key: 'home', scope: 'authenticated', path: '/', component: Page })
    expect(() => createDashboardRouter(shellTree())).toThrow(/"home" path "\/"/)
  })

  it('refuses a root route whose params only differ in name from another page', () => {
    pluginRoutes.add({ key: 'shop', scope: 'public', path: '/$slug', component: Page })
    expect(() => createDashboardRouter(shellTree())).toThrow(/"shop" path "\/\$slug"/)
  })

  it('refuses two root routes on the same path', () => {
    pluginRoutes.add({ key: 'a', scope: 'public', path: '/account', component: Page })
    pluginRoutes.add({ key: 'b', scope: 'authenticated', path: '/account/', component: Page })
    expect(() => createDashboardRouter(shellTree())).toThrow(/"b" path "\/account\/"/)
  })
})
