import type {
  AdminUser,
  AuthTokens,
  InvitationAcceptParams,
  PasswordResetParams,
  SetupParams,
} from '@spree/admin-sdk'
import { createContext, type ReactNode, useCallback, useEffect, useRef, useState } from 'react'
import { getApiClient, type PanelSession } from '../api-client'
import { ADMIN_LOCALE_STORAGE_KEY, switchLocale } from '../lib/i18n'

interface AuthContextValue {
  user: AdminUser | null
  token: string | null
  isAuthenticated: boolean
  isInitializing: boolean
  isLoading: boolean
  login: (email: string, password: string) => Promise<AuthTokens>
  logout: () => Promise<void>
  acceptInvitation: (
    id: string,
    token: string,
    params: InvitationAcceptParams,
  ) => Promise<AuthTokens>
  /**
   * Complete first-run setup (create the first admin account) and sign in —
   * the endpoint issues a session just like login. `setupStatus` (the
   * availability check) is unauthenticated and lives on `adminClient`.
   * Resolves with the session so the caller can route straight to the store
   * it just claimed.
   */
  completeSetup: (params: SetupParams) => Promise<AuthTokens>
  /**
   * Consume a password reset token, set the new password, and sign in — the
   * endpoint issues a session just like login. `requestPasswordReset` (the
   * step that sends the email) is unauthenticated and lives on `adminClient`.
   */
  resetPassword: (token: string, params: PasswordResetParams) => Promise<AuthTokens>
  /**
   * Merge updated fields into the authenticated user (e.g. after a profile
   * save) so context consumers like the top-bar reflect the change immediately
   * instead of waiting for the next token refresh. No-op when signed out.
   */
  updateUser: (changes: Partial<AdminUser>) => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

// Refresh ~30s before the JWT expires (default 5min TTL).
const REFRESH_INTERVAL_MS = 4 * 60 * 1000 + 30 * 1000

/**
 * Reaches an admin-only sign-in flow. A seller's panel has none of these, so
 * calling one there is a bug in the host rather than a runtime condition to
 * handle — it fails here with a name rather than as `undefined is not a
 * function` somewhere further away.
 */
function requireAuthMethod<K extends 'acceptInvitation' | 'resetPassword' | 'completeSetup'>(
  name: K,
  // The three flows take different arguments; their concrete types live on
  // each panel's own client, so this signature stays deliberately loose.
): (...args: any[]) => Promise<PanelSession> {
  const method = getApiClient().auth[name] as
    | ((...args: any[]) => Promise<PanelSession>)
    | undefined
  if (typeof method !== 'function') {
    throw new Error(`@spree/dashboard-core: this panel's API client has no auth.${name}()`)
  }

  return method.bind(getApiClient().auth) as (...args: any[]) => Promise<PanelSession>
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(null)
  const [user, setUser] = useState<AdminUser | null>(null)
  const [isInitializing, setIsInitializing] = useState(true)
  const [isLoading, setIsLoading] = useState(false)
  const refreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  // Serialize concurrent refresh calls so StrictMode/HMR/401-retry don't double-rotate.
  const refreshPromiseRef = useRef<Promise<boolean> | null>(null)

  const clearRefreshTimer = useCallback(() => {
    if (refreshTimerRef.current) {
      clearTimeout(refreshTimerRef.current)
      refreshTimerRef.current = null
    }
  }, [])

  const applySession = useCallback((accessToken: string, authUser: AdminUser) => {
    getApiClient().setToken(accessToken)
    setToken(accessToken)
    setUser(authUser)
    // The account's saved admin language is the source of truth across devices.
    // Compare against the persisted choice (not the live i18n.language): if they
    // already agree, the page booted in the right language and no reload is
    // needed — this also prevents a reload loop on the periodic token refresh.
    const code = authUser.selected_locale
    const stored =
      typeof localStorage !== 'undefined'
        ? (localStorage.getItem(ADMIN_LOCALE_STORAGE_KEY) ?? 'en')
        : 'en'
    if (code && code !== stored) switchLocale(code)
  }, [])

  const updateUser = useCallback((changes: Partial<AdminUser>) => {
    setUser((current) => (current ? { ...current, ...changes } : current))
  }, [])

  const clearSession = useCallback(() => {
    const client = getApiClient()
    client.setToken('')
    // The tenant header is session state too — the store on the admin panel,
    // the seller on a seller's. Left set, it would ride into the next
    // principal's first requests (permissions, the index redirect) and 403
    // them against a tenant they may hold no role on.
    client.clearTenant?.()
    setToken(null)
    setUser(null)
    clearRefreshTimer()
  }, [clearRefreshTimer])

  const doRefresh = useCallback(async (): Promise<boolean> => {
    try {
      const res = await getApiClient().auth.refresh()
      applySession(res.token, res.user)
      return true
    } catch {
      clearSession()
      return false
    }
  }, [applySession, clearSession])

  const refreshAccessToken = useCallback((): Promise<boolean> => {
    if (refreshPromiseRef.current) return refreshPromiseRef.current
    const promise = doRefresh().finally(() => {
      refreshPromiseRef.current = null
    })
    refreshPromiseRef.current = promise
    return promise
  }, [doRefresh])

  const scheduleRefresh = useCallback(() => {
    clearRefreshTimer()
    refreshTimerRef.current = setTimeout(async () => {
      const success = await refreshAccessToken()
      if (success) scheduleRefresh()
    }, REFRESH_INTERVAL_MS)
  }, [refreshAccessToken, clearRefreshTimer])

  // Returns the response so callers that need something from it — the setup
  // screen reads the new store's id to land on — don't have to wait for the
  // provider's state to settle.
  const establish = useCallback(
    async (req: Promise<AuthTokens>) => {
      setIsLoading(true)
      try {
        const res = await req
        applySession(res.token, res.user)
        scheduleRefresh()
        return res
      } finally {
        setIsLoading(false)
      }
    },
    [applySession, scheduleRefresh],
  )

  const login = useCallback(
    (email: string, password: string) => establish(getApiClient().auth.login({ email, password })),
    [establish],
  )

  const acceptInvitation = useCallback(
    (id: string, token: string, params: InvitationAcceptParams) =>
      establish(requireAuthMethod('acceptInvitation')(id, token, params)),
    [establish],
  )

  const resetPassword = useCallback(
    (token: string, params: PasswordResetParams) =>
      establish(requireAuthMethod('resetPassword')(token, params)),
    [establish],
  )

  const completeSetup = useCallback(
    (params: SetupParams) => establish(requireAuthMethod('completeSetup')(params)),
    [establish],
  )

  const logout = useCallback(async () => {
    try {
      await getApiClient().auth.logout()
    } catch {
      // Server unreachable — clear locally; the row will expire naturally.
    } finally {
      clearSession()
    }
  }, [clearSession])

  // biome-ignore lint/correctness/useExhaustiveDependencies: only run on mount
  useEffect(() => {
    getApiClient().onUnauthorized(async () => {
      const success = await refreshAccessToken()
      if (success) scheduleRefresh()
      return success
    })
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // biome-ignore lint/correctness/useExhaustiveDependencies: only run on mount
  useEffect(() => {
    refreshAccessToken()
      .then((success) => {
        if (success) scheduleRefresh()
      })
      .finally(() => setIsInitializing(false))
    return clearRefreshTimer
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isAuthenticated: !!token,
        isInitializing,
        isLoading,
        login,
        logout,
        acceptInvitation,
        completeSetup,
        resetPassword,
        updateUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}
