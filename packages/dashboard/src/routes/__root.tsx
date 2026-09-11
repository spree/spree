import { RouteAnnouncer } from '@spree/dashboard-core'
import { Toaster } from '@spree/dashboard-ui'
import { createRootRoute, Outlet } from '@tanstack/react-router'

export const Route = createRootRoute({
  component: RootLayout,
})

function RootLayout() {
  return (
    <>
      <Outlet />
      {/* Mounted above every route, signed in or not, so the tab title and the
          navigation announcement follow the page wherever it goes. */}
      <RouteAnnouncer />
      <Toaster />
    </>
  )
}
