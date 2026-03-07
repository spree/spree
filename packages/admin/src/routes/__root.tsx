import { createRootRouteWithContext, Outlet } from '@tanstack/react-router'

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
  return <Outlet />
}
