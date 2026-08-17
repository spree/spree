import { useAuth } from '@spree/dashboard-core'
import { createFileRoute, Navigate } from '@tanstack/react-router'
import { LoginPage } from '../pages/login'

export const Route = createFileRoute('/login')({
  component: Login,
})

function Login() {
  const { isInitializing, isAuthenticated } = useAuth()
  if (isInitializing) return null
  // A live session landing on /login goes where it was headed instead.
  if (isAuthenticated) return <Navigate to="/" replace />
  return <LoginPage />
}
