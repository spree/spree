import { createContext, type ReactNode, useCallback, useEffect, useRef, useState } from 'react'
import { adminClient } from '@/client'
import { router } from '@/router'

interface AuthUser {
  id: string
  email: string
  first_name: string | null
  last_name: string | null
}

interface AuthContextValue {
  user: AuthUser | null
  token: string | null
  isAuthenticated: boolean
  /** True while the cold-load `/auth/refresh` bootstrap is in flight. Routes should wait. */
  isInitializing: boolean
  /** True while the user is actively signing in (login form). */
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

export const AuthContext = createContext<AuthContextValue | null>(null)

// Refresh ~30s before the JWT expires (default 5min TTL).
// 401s on slow requests are still handled via adminClient.onUnauthorized retry.
const REFRESH_INTERVAL_MS = 4 * 60 * 1000 + 30 * 1000

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(null)
  const [user, setUser] = useState<AuthUser | null>(null)
  const [isInitializing, setIsInitializing] = useState(true)
  const [isLoading, setIsLoading] = useState(false)
  const refreshTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  // Serialize all refresh calls — prevents double-rotation from StrictMode/HMR.
  const refreshPromiseRef = useRef<Promise<boolean> | null>(null)

  const clearRefreshTimer = useCallback(() => {
    if (refreshTimerRef.current) {
      clearTimeout(refreshTimerRef.current)
      refreshTimerRef.current = null
    }
  }, [])

  // beforeLoad guards capture context at navigation time. Invalidate the router
  // here so any pending guards re-run with the fresh auth state.
  const applySession = useCallback((accessToken: string, authUser: AuthUser) => {
    adminClient.setToken(accessToken)
    setToken(accessToken)
    setUser(authUser)
    router.invalidate()
  }, [])

  const clearSession = useCallback(() => {
    adminClient.setToken('')
    setToken(null)
    setUser(null)
    clearRefreshTimer()
    router.invalidate()
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

  // Serialize: if a refresh is already in flight, await the same promise.
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

  const login = useCallback(
    async (email: string, password: string) => {
      setIsLoading(true)
      try {
        const res = await adminClient.auth.login({ email, password })
        applySession(res.token, res.user)
        scheduleRefresh()
      } finally {
        setIsLoading(false)
      }
    },
    [applySession, scheduleRefresh],
  )

  const logout = useCallback(async () => {
    try {
      await adminClient.auth.logout()
    } catch {
      // Network/server failures shouldn't trap the user — clear locally regardless.
      // The server-side refresh row will expire naturally if the call didn't reach it.
    } finally {
      clearSession()
    }
  }, [clearSession])

  // Register the 401 handler: refresh token (driven by cookie) and let the SDK retry.
  // biome-ignore lint/correctness/useExhaustiveDependencies: only run on mount
  useEffect(() => {
    adminClient.onUnauthorized(async () => {
      const success = await refreshAccessToken()
      if (success) scheduleRefresh()
      return success
    })
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  // Cold-load bootstrap: try to refresh from the cookie. If we get an access token,
  // hydrate the in-memory state. If not, stay logged out — routes will redirect to /login.
  // biome-ignore lint/correctness/useExhaustiveDependencies: only run on mount
  useEffect(() => {
    refreshAccessToken()
      .then((success) => {
        if (success) scheduleRefresh()
      })
      .finally(() => {
        setIsInitializing(false)
        // Guards return early while isInitializing — invalidate so they re-run
        // now that the cold-load decision has settled.
        router.invalidate()
      })
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
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}
