// @vitest-environment happy-dom
import type { AdminUser, AuthTokens } from '@spree/admin-sdk'
import { act, createElement } from 'react'
import { createRoot, type Root } from 'react-dom/client'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { type PanelApiClient, setApiClient } from '../src/api-client'
import { useAuth } from '../src/hooks/use-auth'
import { queryClient } from '../src/lib/query-client'
import { AuthProvider } from '../src/providers/auth-provider'

// Tells React this environment supports `act`.
;(globalThis as { IS_REACT_ACT_ENVIRONMENT?: boolean }).IS_REACT_ACT_ENVIRONMENT = true

const session: AuthTokens = {
  token: 'jwt-from-host-endpoint',
  user: { id: 'admin_1', email: 'owner@example.com' } as AdminUser,
}

let auth: ReturnType<typeof useAuth>
let client: PanelApiClient
let root: Root | null = null

function Probe() {
  auth = useAuth()
  return null
}

function deferred<T>() {
  let resolve!: (value: T) => void
  let reject!: (error: unknown) => void
  const promise = new Promise<T>((res, rej) => {
    resolve = res
    reject = rej
  })
  return { promise, resolve, reject }
}

/** Mounts the provider; `refresh` answers the boot-time refresh. */
async function mount(refresh: () => Promise<AuthTokens>) {
  client = {
    auth: { login: vi.fn(), refresh: vi.fn(refresh), logout: vi.fn().mockResolvedValue(undefined) },
    setToken: vi.fn(),
    onUnauthorized: vi.fn(),
    clearTenant: vi.fn(),
    fetchPermissions: vi.fn(),
  } as unknown as PanelApiClient
  setApiClient(client)

  root = createRoot(document.createElement('div'))
  await act(async () => {
    root?.render(createElement(AuthProvider, null, createElement(Probe)))
  })
}

/** Runs a refresh the way a 401 does, through the handler the provider registered. */
async function refreshAfterUnauthorized() {
  const handler = vi.mocked(client.onUnauthorized).mock.calls[0][0]
  await act(async () => {
    await handler()
  })
}

// Signed out on boot: no refresh cookie yet.
const signedOut = () => Promise.reject(new Error('401'))

afterEach(() => {
  act(() => root?.unmount())
  root = null
})

describe('AuthProvider establishSession', () => {
  it('signs in with a session issued by another endpoint', async () => {
    await mount(signedOut)
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
    await mount(signedOut)
    const request = deferred<AuthTokens>()

    let established!: Promise<AuthTokens>
    act(() => {
      established = auth.establishSession(request.promise)
    })
    expect(auth.isLoading).toBe(true)

    await act(async () => {
      request.resolve(session)
      await established
    })
    expect(auth.isLoading).toBe(false)
    expect(auth.isAuthenticated).toBe(true)
  })

  it('stays signed out when the request fails', async () => {
    await mount(signedOut)

    await act(async () => {
      await expect(auth.establishSession(Promise.reject(new Error('422')))).rejects.toThrow('422')
    })

    expect(auth.isAuthenticated).toBe(false)
    expect(auth.isLoading).toBe(false)
  })

  it('keeps the session when a boot refresh started earlier fails afterwards', async () => {
    const boot = deferred<AuthTokens>()
    await mount(() => boot.promise)

    await act(async () => {
      await auth.establishSession(session)
    })
    await act(async () => boot.reject(new Error('401')))

    expect(auth.isAuthenticated).toBe(true)
    expect(auth.token).toBe('jwt-from-host-endpoint')
  })

  it('keeps the session when a boot refresh started earlier succeeds afterwards', async () => {
    const boot = deferred<AuthTokens>()
    await mount(() => boot.promise)

    await act(async () => {
      await auth.establishSession(session)
    })
    await act(async () =>
      boot.resolve({ token: 'stale-boot-token', user: { id: 'admin_2' } as AdminUser }),
    )

    expect(auth.token).toBe('jwt-from-host-endpoint')
    expect(auth.user?.id).toBe('admin_1')
  })

  it('does not sign back in when the user signs out while the request is pending', async () => {
    await mount(signedOut)
    const request = deferred<AuthTokens>()

    let established!: Promise<AuthTokens>
    act(() => {
      established = auth.establishSession(request.promise)
    })
    await act(async () => {
      await auth.logout()
    })
    await act(async () => {
      request.resolve(session)
      await expect(established).rejects.toThrow('superseded')
    })

    expect(auth.isAuthenticated).toBe(false)
  })

  it('keeps the newer session when an older request resolves after it', async () => {
    await mount(signedOut)
    const older = deferred<AuthTokens>()
    const newer = deferred<AuthTokens>()

    let olderEstablished!: Promise<AuthTokens>
    let newerEstablished!: Promise<AuthTokens>
    act(() => {
      olderEstablished = auth.establishSession(older.promise)
      newerEstablished = auth.establishSession(newer.promise)
    })
    await act(async () => {
      newer.resolve(session)
      await newerEstablished
    })
    await act(async () => {
      older.resolve({ token: 'older-token', user: { id: 'admin_2' } as AdminUser })
      await expect(olderEstablished).rejects.toThrow('superseded')
    })

    expect(auth.token).toBe('jwt-from-host-endpoint')
    expect(auth.user?.id).toBe('admin_1')
  })

  it("drops the previous account's cached data when a different account signs in", async () => {
    await mount(signedOut)
    await act(async () => {
      await auth.establishSession(session)
    })
    queryClient.setQueryData(['permissions'], { rules: ['previous account'] })

    await act(async () => {
      await auth.establishSession({ token: 'other', user: { id: 'admin_2' } as AdminUser })
    })

    expect(queryClient.getQueryData(['permissions'])).toBeUndefined()
    expect(client.clearTenant).toHaveBeenCalled()
    expect(auth.user?.id).toBe('admin_2')
  })

  it('stays loading until the last of overlapping requests settles', async () => {
    await mount(signedOut)
    const older = deferred<AuthTokens>()
    const newer = deferred<AuthTokens>()

    let olderEstablished!: Promise<AuthTokens>
    let newerEstablished!: Promise<AuthTokens>
    act(() => {
      olderEstablished = auth.establishSession(older.promise)
      newerEstablished = auth.establishSession(newer.promise)
    })
    await act(async () => {
      older.resolve(session)
      await expect(olderEstablished).rejects.toThrow('superseded')
    })
    expect(auth.isLoading).toBe(true)

    await act(async () => {
      newer.resolve(session)
      await newerEstablished
    })
    expect(auth.isLoading).toBe(false)
  })

  it('keeps a session that started while a logout request was in flight', async () => {
    await mount(signedOut)
    await act(async () => {
      await auth.establishSession(session)
    })
    const logoutRequest = deferred<void>()
    vi.mocked(client.auth.logout).mockReturnValueOnce(logoutRequest.promise)

    let loggedOut!: Promise<void>
    act(() => {
      loggedOut = auth.logout()
    })
    const next = { token: 'next-session', user: { id: 'admin_2' } as AdminUser }
    await act(async () => {
      await auth.establishSession(next)
    })
    await act(async () => {
      logoutRequest.resolve()
      await loggedOut
    })

    expect(auth.isAuthenticated).toBe(true)
    expect(auth.token).toBe('next-session')
  })
})

describe('AuthProvider refresh', () => {
  it("keeps the same account's cached data across a refresh", async () => {
    await mount(() => Promise.resolve(session))
    queryClient.setQueryData(['store'], { id: 'store_1' })
    vi.mocked(client.auth.refresh).mockResolvedValueOnce({ ...session, token: 'rotated' })

    await refreshAfterUnauthorized()

    expect(auth.token).toBe('rotated')
    expect(queryClient.getQueryData(['store'])).toEqual({ id: 'store_1' })
    expect(client.clearTenant).not.toHaveBeenCalled()
  })

  it("keeps the same account's cached data when the same account signs in again", async () => {
    await mount(signedOut)
    await act(async () => {
      await auth.establishSession(session)
    })
    queryClient.setQueryData(['store'], { id: 'store_1' })
    // The failed boot refresh already cleared once.
    vi.mocked(client.clearTenant!).mockClear()

    await act(async () => {
      await auth.establishSession({ ...session, token: 'again' })
    })

    expect(queryClient.getQueryData(['store'])).toEqual({ id: 'store_1' })
    expect(client.clearTenant).not.toHaveBeenCalled()
  })

  it("drops the previous account's cached data when a refresh returns another account", async () => {
    await mount(() => Promise.resolve(session))
    queryClient.setQueryData(['permissions'], { rules: ['previous account'] })
    vi.mocked(client.auth.refresh).mockResolvedValueOnce({
      token: 'other-tab',
      user: { id: 'admin_2' } as AdminUser,
    })

    await refreshAfterUnauthorized()

    expect(queryClient.getQueryData(['permissions'])).toBeUndefined()
    expect(auth.user?.id).toBe('admin_2')
  })
})
