import type { AdminUser } from '@spree/admin-sdk'
import {
  AuthContext,
  NO_STORE_ACCESS_SLOT,
  type NoStoreAccessSlotContext,
  registerSlot,
  removeSlot,
} from '@spree/dashboard-core'
import { ThemeProvider } from '@spree/dashboard-ui'
import type { ContextType } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it } from 'vitest'
import { Route as IndexRoute } from '../../routes/_authenticated/index'
import { NoStoreAccess } from './no-store-access'

const storelessUser = {
  id: 'admin_1',
  email: 'new-merchant@example.com',
  stores: [],
  roles: [],
} as unknown as AdminUser

const signOut = async () => {}

function renderIndexRoute(user: AdminUser) {
  const IndexRedirect = IndexRoute.options.component!
  const auth = { user, logout: signOut } as unknown as NonNullable<ContextType<typeof AuthContext>>

  return renderToStaticMarkup(
    <ThemeProvider>
      <AuthContext.Provider value={auth}>
        <IndexRedirect />
      </AuthContext.Provider>
    </ThemeProvider>,
  )
}

describe('the no store access screen', () => {
  afterEach(() => removeSlot(NO_STORE_ACCESS_SLOT, 'create-store'))

  it('is what the index route renders for a user who holds no store', () => {
    const html = renderIndexRoute(storelessUser)

    expect(html).toContain('You don&#x27;t have access to any store')
    expect(html).toContain('Signed in as new-merchant@example.com')
    expect(html).toContain('Sign out')
  })

  it('is replaced by a plugin registered on its slot', () => {
    function CreateStore({ user }: NoStoreAccessSlotContext) {
      return <a href="https://platform.example.com/new-store">Create a store for {user.email}</a>
    }
    registerSlot<NoStoreAccessSlotContext>(NO_STORE_ACCESS_SLOT, {
      id: 'create-store',
      component: CreateStore,
    })

    const html = renderToStaticMarkup(<NoStoreAccess user={storelessUser} signOut={signOut} />)

    expect(html).toContain('Create a store for new-merchant@example.com')
    expect(html).not.toContain('Sign out')
  })
})
