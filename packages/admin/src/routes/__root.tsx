import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'
import { Toaster } from 'sonner'
import type { Permissions } from '@/providers/permission-provider'

interface RouterContext {
  auth: {
    isAuthenticated: boolean
    isInitializing: boolean
    token: string | null
  }
  permissions: Permissions
}

export const Route = createRootRouteWithContext<RouterContext>()({
  component: RootLayout,
})

function RootLayout() {
  return (
    <>
      <Outlet />
      <Toaster position="bottom-right" richColors />
    </>
  )
}
