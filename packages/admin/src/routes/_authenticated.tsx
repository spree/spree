import { createFileRoute, Navigate, Outlet } from '@tanstack/react-router'
import { useAuth } from '@/hooks/use-auth'

export const Route = createFileRoute('/_authenticated')({
  component: AuthenticatedLayout,
})

function AuthenticatedLayout() {
  const { isInitializing, isAuthenticated } = useAuth()
  if (isInitializing) return null
  if (!isAuthenticated) return <Navigate to="/login" replace />
  return <Outlet />
}
