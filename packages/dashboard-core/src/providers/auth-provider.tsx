import type {
  AdminUser,
  AuthTokens,
  InvitationAcceptParams,
  PasswordResetParams,
  SetupParams,
} from '@spree/admin-sdk'
import { createContext, type ReactNode, useCallback, useEffect, useRef, useState } from 'react'
import { getApiClient, type PanelSession } from '../api-client'
import { ADMIN_LOCALE_STORAGE_KEY, sessionLocale, switchLocale } from '../lib/i18n'
import { queryClient } from '../lib/query-client'

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
   * Sign in with a session the host obtained from an endpoint of its own —
   * one that responds like login and sets the refresh cookie. Pass the
   * pending request to get `isLoading` while it runs, or the response once it
   * has arrived. Periodic refresh takes over from there, as after `login`.
   */
  establishSession: (session: AuthTokens | Promise<AuthTokens>) => Promise<AuthTokens>
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
  // Bumped whenever a session starts or ends, so a refresh that was already in
  // flight (the boot refresh racing a host's establishSession, say) can tell
  // its answer is stale and must not sign the new session out or replace it.
  const sessionGenerationRef = useRef(0)
  // Bumped by every sign-in attempt and by logout: a sign-in request that
  // resolves after a newer attempt, or after the user signed out, must not
  // apply its session. Refresh failures leave it alone — a failed boot refresh
  // is how every signed-out visit starts.
  const signInGenerationRef = useRef(0)
  const userIdRef = useRef<string | null>(null)
  const pendingSignInsRef = useRef(0)

  const clearRefreshTimer = useCallback(() => {
    if (refreshTimerRef.current) {
      clearTimeout(refreshTimerRef.current)
      refreshTimerRef.current = null
    }
  }, [])

  const applySession = useCallback((accessToken: string, authUser: AdminUser) => {
    getApiClient().setToken(accessToken)
    userIdRef.current = authUser.id
    setToken(accessToken)
    setUser(authUser)
    // The account's saved admin language is the source of truth across devices.
    // Compare against the persisted choice (not the live i18n.language): if they
    // already agree, the page booted in the right language and no reload is
    // needed — this also prevents a reload loop on the periodic token refresh.
    const stored =
      typeof localStorage !== 'undefined'
        ? (localStorage.getItem(ADMIN_LOCALE_STORAGE_KEY) ?? 'en')
        : 'en'
    const target = sessionLocale(authUser.selected_locale, stored)
    if (target) switchLocale(target)
  }, [])

  const updateUser = useCallback((changes: Partial<AdminUser>) => {
    setUser((current) => (current ? { ...current, ...changes } : current))
  }, [])

  const clearSession = useCallback(() => {
    sessionGenerationRef.current += 1
    userIdRef.current = null
    const client = getApiClient()
    client.setToken('')
    // The tenant header is session state too — the store on the admin panel,
    // the seller on a seller's. Left set, it would ride into the next
    // principal's first requests (permissions, the index redirect) and 403
    // them against a tenant they may hold no role on.
    client.clearTenant?.()
    // Everything fetched as the previous principal, permissions included. The
    // permission query stops running once `isAuthenticated` goes false, but its
    // cached rules survive — so the next admin to sign in on this browser would
    // render the last one's navigation and action buttons until the refetch
    // landed. Server-side authorization is unaffected either way; this is about
    // not showing one principal what another may do.
    queryClient.clear()
    setToken(null)
    setUser(null)
    clearRefreshTimer()
  }, [clearRefreshTimer])

  // A different account (signed in from another tab, or through a host's own
  // endpoint): drop what was cached for the previous one, permissions above
  // all, before the new one renders.
  const clearIfAccountChanged = useCallback(
    (nextUserId: string) => {
      if (userIdRef.current && userIdRef.current !== nextUserId) clearSession()
    },
    [clearSession],
  )

  const doRefresh = useCallback(async (): Promise<boolean> => {
    const generation = sessionGenerationRef.current
    try {
      const res = await getApiClient().auth.refresh()
      if (generation !== sessionGenerationRef.current) return false
      clearIfAccountChanged(res.user.id)
      applySession(res.token, res.user)
      return true
    } catch {
      if (generation !== sessionGenerationRef.current) return false
      clearSession()
      return false
    }
  }, [applySession, clearSession, clearIfAccountChanged])

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
    async (req: AuthTokens | Promise<AuthTokens>) => {
      const generation = ++signInGenerationRef.current
      pendingSignInsRef.current += 1
      setIsLoading(true)
      try {
        const res = await req
        if (generation !== signInGenerationRef.current) {
          throw new Error(
            '@spree/dashboard-core: superseded by a newer sign-in or a sign-out before the session was established',
          )
        }
        clearIfAccountChanged(res.user.id)
        sessionGenerationRef.current += 1
        applySession(res.token, res.user)
        scheduleRefresh()
        return res
      } finally {
        // Overlapping attempts: stay loading until the last one settles.
        pendingSignInsRef.current -= 1
        setIsLoading(pendingSignInsRef.current > 0)
      }
    },
    [applySession, clearIfAccountChanged, scheduleRefresh],
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
    // Logout wins: any sign-in or refresh still in flight is discarded.
    signInGenerationRef.current += 1
    sessionGenerationRef.current += 1
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
        establishSession: establish,
        updateUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}
