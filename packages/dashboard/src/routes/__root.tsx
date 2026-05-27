import { Toaster } from '@spree/dashboard-ui'
import { createRootRoute, Outlet } from '@tanstack/react-router'

export const Route = createRootRoute({
  component: RootLayout,
})

function RootLayout() {
  return (
    <>
      <Outlet />
      <Toaster position="bottom-right" />
    </>
  )
}
