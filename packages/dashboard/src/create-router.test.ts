import { __resetPluginRoutes, pluginRoutes } from '@spree/dashboard-core'
import {
  type AnyRoute,
  type AnyRouter,
  createMemoryHistory,
  createRootRoute,
  createRoute,
  RouterProvider,
} from '@tanstack/react-router'
import { createElement } from 'react'
import { renderToString } from 'react-dom/server'
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

  it('leaves the generated tree untouched, so every router built from it is the same', () => {
    pluginRoutes.add({ key: 'sign-up', scope: 'public', path: '/sign-up', component: Page })
    pluginRoutes.add({ key: 'account', scope: 'authenticated', path: '/account', component: Page })
    const tree = shellTree()
    const authenticated = (tree.children as unknown as AnyRoute[]).find(
      (r) => (r.options as { id?: string }).id === '/_authenticated',
    ) as AnyRoute
    const rootChildren = tree.children
    const authenticatedChildren = authenticated.children

    const first = createDashboardRouter(tree)
    const second = createDashboardRouter(tree)

    expect(tree.children).toBe(rootChildren)
    expect(tree.children).toHaveLength(2)
    expect(authenticated.children).toBe(authenticatedChildren)
    expect(authenticated.children).toHaveLength(2)
    expect(Object.keys(second.routesById)).toEqual(Object.keys(first.routesById))
    expect(Object.keys(second.routesById)).toEqual(
      expect.arrayContaining(['/sign-up', '/_authenticated/account']),
    )
  })

  it('renders a root registry route through the auth layout, for every router built', async () => {
    pluginRoutes.add({
      key: 'welcome',
      scope: 'authenticated',
      path: '/welcome/$step',
      component: ({ params }) => createElement('p', null, `step ${params.step}`),
    })
    const tree = shellTree()

    for (let build = 0; build < 2; build++) {
      const router = createDashboardRouter(tree)
      router.update({ history: createMemoryHistory({ initialEntries: ['/welcome/2'] }) })
      await router.load()
      const html = renderToString(createElement(RouterProvider, { router: router as AnyRouter }))
      expect(html).toContain('step 2')
    }
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
