import { useAuth } from '@spree/dashboard-core'
import { createFileRoute, Navigate } from '@tanstack/react-router'
import { ForgotPasswordPage } from '../pages/forgot-password'

export const Route = createFileRoute('/forgot-password')({
  component: ForgotPassword,
})

function ForgotPassword() {
  const { isInitializing, isAuthenticated } = useAuth()
  if (isInitializing) return null
  // Someone already signed in has no use for a reset link.
  if (isAuthenticated) return <Navigate to="/" replace />
  return <ForgotPasswordPage />
}
