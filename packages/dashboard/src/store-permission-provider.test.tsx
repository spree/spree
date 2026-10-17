// @vitest-environment happy-dom
import type { PermissionRule } from '@spree/admin-sdk'
import {
  AuthContext,
  type PanelApiClient,
  setApiClient,
  usePermissions,
} from '@spree/dashboard-core'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import {
  createMemoryHistory,
  createRootRoute,
  createRoute,
  createRouter,
  Outlet,
  RouterProvider,
} from '@tanstack/react-router'
import { act, type ContextType } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { StorePermissionProvider } from './store-permission-provider'

declare global {
  var IS_REACT_ACT_ENVIRONMENT: boolean
}
globalThis.IS_REACT_ACT_ENVIRONMENT = true

const allow = (action: string, subject: string): PermissionRule => ({
  allow: true,
  actions: [action],
  subjects: [subject],
  has_conditions: false,
})

// What `/me` answers for each store the request is sent for. No store, no roles.
const RULES_BY_STORE: Record<string, PermissionRule[]> = {
  store_a: [allow('manage', 'product'), allow('manage', 'order')],
  store_b: [allow('read', 'order')],
}

// Stands in for the admin client's store header, which the store route sets.
let storeHeader = ''
const requestedStores: string[] = []

setApiClient({
  fetchPermissions: async () => {
    requestedStores.push(storeHeader)
    return { rules: RULES_BY_STORE[storeHeader] ?? [], keys: [] }
  },
} as unknown as PanelApiClient)

function Probe() {
  const { permissions } = usePermissions()

  return (
    <p>
      products:{String(permissions.can('read', 'product'))} orders:
      {String(permissions.can('read', 'order'))}
    </p>
  )
}

function buildRouter(initialPath: string) {
  const rootRoute = createRootRoute({ component: Outlet })
  const routeTree = rootRoute.addChildren([
    createRoute({ getParentRoute: () => rootRoute, path: '/', component: Probe }),
    createRoute({
      getParentRoute: () => rootRoute,
      path: '$storeId',
      beforeLoad: ({ params }) => {
        storeHeader = params.storeId
      },
      component: Probe,
    }),
  ])

  return createRouter({
    routeTree,
    history: createMemoryHistory({ initialEntries: [initialPath] }),
  })
}

let root: Root | undefined

async function renderAt(initialPath: string) {
  const router = buildRouter(initialPath)
  const queryClient = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  const auth = { isAuthenticated: true } as ContextType<typeof AuthContext>
  const container = document.createElement('div')
  document.body.append(container)
  root = createRoot(container)

  await act(async () => {
    root?.render(
      <QueryClientProvider client={queryClient}>
        <AuthContext.Provider value={auth}>
          <StorePermissionProvider router={router}>
            <RouterProvider router={router} />
          </StorePermissionProvider>
        </AuthContext.Provider>
      </QueryClientProvider>,
    )
  })

  const navigate = (to: string) => act(() => router.navigate({ to }))
  const text = () => container.textContent

  return { navigate, text }
}

describe('StorePermissionProvider', () => {
  afterEach(() => {
    act(() => root?.unmount())
    document.body.innerHTML = ''
    storeHeader = ''
    requestedStores.length = 0
  })

  it('loads the store’s permissions when opening a store from a page outside any store', async () => {
    const { navigate, text } = await renderAt('/')
    await vi.waitFor(() => expect(requestedStores).toEqual(['']))
    expect(text()).toBe('products:false orders:false')

    await navigate('/store_a')

    await vi.waitFor(() => expect(text()).toBe('products:true orders:true'))
    expect(requestedStores).toEqual(['', 'store_a'])
  })

  it('switches to the other store’s permissions when switching store', async () => {
    const { navigate, text } = await renderAt('/store_a')
    await vi.waitFor(() => expect(text()).toBe('products:true orders:true'))

    await navigate('/store_b')

    await vi.waitFor(() => expect(text()).toBe('products:false orders:true'))
    expect(requestedStores.filter((store) => store === 'store_b')).toHaveLength(1)
  })
})
