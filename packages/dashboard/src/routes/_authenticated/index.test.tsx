import {
  __resetSlotRegistry,
  registerSlot,
  STORE_SELECTION_SLOT,
  type StoreSelectionSlotContext,
} from '@spree/dashboard-core'
import type { ComponentType } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it, vi } from 'vitest'

const auth = vi.hoisted(() => ({
  user: null as { email: string; stores: Array<{ id: string; name: string }> } | null,
  logout: async () => {},
}))

vi.mock('@spree/dashboard-core', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@spree/dashboard-core')>()),
  useAuth: () => auth,
}))
vi.mock('@tanstack/react-router', async (importOriginal) => ({
  ...(await importOriginal<typeof import('@tanstack/react-router')>()),
  Navigate: ({ params }: { params: { storeId: string } }) => `navigate:${params.storeId}`,
}))
vi.mock('../../components/spree/auth-shell', () => ({
  AuthShell: ({ children }: { children: React.ReactNode }) => children,
}))

const { Route } = await import('./index')
const StoreSelection = Route.options.component as ComponentType

describe('signed-in landing page', () => {
  afterEach(() => __resetSlotRegistry())

  it('opens the first store by default', () => {
    auth.user = { email: 'a@example.com', stores: [{ id: 'store_1', name: 'One' }] }
    expect(renderToStaticMarkup(<StoreSelection />)).toBe('navigate:store_1')
  })

  it('explains a user with no store has no access by default', () => {
    auth.user = { email: 'a@example.com', stores: [] }
    expect(renderToStaticMarkup(<StoreSelection />)).toContain('a@example.com')
  })

  it('hands the whole page to a store_selection replacement, with or without stores', () => {
    registerSlot<StoreSelectionSlotContext>(STORE_SELECTION_SLOT, {
      id: 'store-list',
      component: ({ user }) => <p>{user.stores.map((store) => store.name).join(',') || 'none'}</p>,
    })

    auth.user = { email: 'a@example.com', stores: [{ id: 'store_1', name: 'One' }] }
    expect(renderToStaticMarkup(<StoreSelection />)).toBe('<p>One</p>')

    auth.user = { email: 'a@example.com', stores: [] }
    expect(renderToStaticMarkup(<StoreSelection />)).toBe('<p>none</p>')
  })
})
