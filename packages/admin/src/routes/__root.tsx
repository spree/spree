import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'
import { Toaster } from 'sonner'

interface RouterContext {
  auth: {
    isAuthenticated: boolean
    token: string | null
  }
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
