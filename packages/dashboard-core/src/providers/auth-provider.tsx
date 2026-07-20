import type {
  AdminUser,
  AuthTokens,
  InvitationAcceptParams,
  PasswordResetParams,
} from '@spree/admin-sdk'
import { createContext, type ReactNode, useCallback, useEffect, useRef, useState } from 'react'
import { adminClient } from '../client'
import { ADMIN_LOCALE_STORAGE_KEY, switchLocale } from '../lib/i18n'

interface AuthContextValue {
  user: AdminUser | null
  token: string | null
  isAuthenticated: boolean
  isInitializing: boolean
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
  acceptInvitation: (id: string, token: string, params: InvitationAcceptParams) => Promise<void>
  /**
   * Consume a password reset token, set the new password, and sign in — the
   * endpoint issues a session just like login. `requestPasswordReset` (the
   * step that sends the email) is unauthenticated and lives on `adminClient`.
   */
  resetPassword: (token: string, params: PasswordResetParams) => Promise<void>
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
    adminClient.setToken(accessToken)
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
    adminClient.setToken('')
    setToken(null)
    setUser(null)
    clearRefreshTimer()
  }, [clearRefreshTimer])

  const doRefresh = useCallback(async (): Promise<boolean> => {
    try {
      const res = await adminClient.auth.refresh()
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

  const establish = useCallback(
    async (req: Promise<AuthTokens>) => {
      setIsLoading(true)
      try {
        const res = await req
        applySession(res.token, res.user)
        scheduleRefresh()
      } finally {
        setIsLoading(false)
      }
    },
    [applySession, scheduleRefresh],
  )

  const login = useCallback(
    (email: string, password: string) => establish(adminClient.auth.login({ email, password })),
    [establish],
  )

  const acceptInvitation = useCallback(
    (id: string, token: string, params: InvitationAcceptParams) =>
      establish(adminClient.auth.acceptInvitation(id, token, params)),
    [establish],
  )

  const resetPassword = useCallback(
    (token: string, params: PasswordResetParams) =>
      establish(adminClient.auth.resetPassword(token, params)),
    [establish],
  )

  const logout = useCallback(async () => {
    try {
      await adminClient.auth.logout()
    } catch {
      // Server unreachable — clear locally; the row will expire naturally.
    } finally {
      clearSession()
    }
  }, [clearSession])

  // biome-ignore lint/correctness/useExhaustiveDependencies: only run on mount
  useEffect(() => {
    adminClient.onUnauthorized(async () => {
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
        resetPassword,
        updateUser,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}
