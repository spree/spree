// @vitest-environment happy-dom
import type { AdminUser, AuthTokens } from '@spree/admin-sdk'
import { act, createElement } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { type PanelApiClient, setApiClient } from '../src/api-client'
import { useAuth } from '../src/hooks/use-auth'
import { AuthProvider } from '../src/providers/auth-provider'

// Tells React this environment supports `act`.
;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

const session: AuthTokens = {
  token: 'jwt-from-host-endpoint',
  user: { id: 'admin_1', email: 'owner@example.com' } as AdminUser,
}

let auth: ReturnType<typeof useAuth>
let client: PanelApiClient
let root: Root

function Probe() {
  auth = useAuth()
  return null
}

beforeEach(async () => {
  client = {
    auth: {
      login: vi.fn(),
      // Signed out on boot: no refresh cookie yet.
      refresh: vi.fn().mockRejectedValue(new Error('401')),
      logout: vi.fn(),
    },
    setToken: vi.fn(),
    onUnauthorized: vi.fn(),
    fetchPermissions: vi.fn(),
  } as unknown as PanelApiClient
  setApiClient(client)

  root = createRoot(document.createElement('div'))
  await act(async () => {
    root.render(createElement(AuthProvider, null, createElement(Probe)))
  })
})

afterEach(() => {
  act(() => root.unmount())
})

describe('AuthProvider establishSession', () => {
  it('signs in with a session issued by another endpoint', async () => {
    expect(auth.isAuthenticated).toBe(false)

    let result: AuthTokens | undefined
    await act(async () => {
      result = await auth.establishSession(session)
    })

    expect(result).toBe(session)
    expect(client.setToken).toHaveBeenLastCalledWith('jwt-from-host-endpoint')
    expect(auth.isAuthenticated).toBe(true)
    expect(auth.token).toBe('jwt-from-host-endpoint')
    expect(auth.user?.email).toBe('owner@example.com')
  })

  it('reports loading while a pending request resolves', async () => {
    let resolve!: (value: AuthTokens) => void
    const pending = new Promise<AuthTokens>((r) => {
      resolve = r
    })

    let established!: Promise<AuthTokens>
    act(() => {
      established = auth.establishSession(pending)
    })
    expect(auth.isLoading).toBe(true)

    await act(async () => {
      resolve(session)
      await established
    })
    expect(auth.isLoading).toBe(false)
    expect(auth.isAuthenticated).toBe(true)
  })

  it('stays signed out when the request fails', async () => {
    await act(async () => {
      await expect(auth.establishSession(Promise.reject(new Error('422')))).rejects.toThrow('422')
    })

    expect(auth.isAuthenticated).toBe(false)
    expect(auth.isLoading).toBe(false)
  })
})
