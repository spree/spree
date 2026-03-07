import { createContext, useCallback, useEffect, useState, type ReactNode } from 'react'
import { spreeClient } from '@/client'

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
  isLoading: boolean
  login: (email: string, password: string) => Promise<void>
  logout: () => void
}

export const AuthContext = createContext<AuthContextValue | null>(null)

const TOKEN_KEY = 'spree_admin_token'
const USER_KEY = 'spree_admin_user'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() =>
    localStorage.getItem(TOKEN_KEY),
  )
  const [user, setUser] = useState<AuthUser | null>(() => {
    const stored = localStorage.getItem(USER_KEY)
    return stored ? JSON.parse(stored) : null
  })
  const [isLoading, setIsLoading] = useState(false)

  const login = useCallback(async (email: string, password: string) => {
    setIsLoading(true)
    try {
      const response = await spreeClient.admin.auth.login({ email, password })
      setToken(response.token)
      setUser(response.user)
      localStorage.setItem(TOKEN_KEY, response.token)
      localStorage.setItem(USER_KEY, JSON.stringify(response.user))
    } finally {
      setIsLoading(false)
    }
  }, [])

  const logout = useCallback(() => {
    setToken(null)
    setUser(null)
    localStorage.removeItem(TOKEN_KEY)
    localStorage.removeItem(USER_KEY)
  }, [])

  useEffect(() => {
    if (!token) return

    spreeClient.admin.auth.refresh({ token }).then((response) => {
      setToken(response.token)
      localStorage.setItem(TOKEN_KEY, response.token)
    }).catch(() => {
      logout()
    })
  }, []) // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isAuthenticated: !!token,
        isLoading,
        login,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  )
}
