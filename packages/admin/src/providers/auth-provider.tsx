import { createContext, type ReactNode, useCallback, useEffect, useRef, useState } from 'react'
import { adminClient } from '@/client'

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
  /** True until the cold-load /auth/refresh bootstrap settles. */
  isInitializing: boolean
  /** True while a login submission is in flight. */
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => Promise<void>
}

export const AuthContext = createContext<AuthContextValue | null>(null)

// Refresh ~30s before the JWT expires (default 5min TTL).
const REFRESH_INTERVAL_MS = 4 * 60 * 1000 + 30 * 1000

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(null)
  const [user, setUser] = useState<AuthUser | null>(null)
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

  const applySession = useCallback((accessToken: string, authUser: AuthUser) => {
    adminClient.setToken(accessToken)
    setToken(accessToken)
    setUser(authUser)
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
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}
