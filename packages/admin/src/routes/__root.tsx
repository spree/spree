import { createRootRoute, Outlet } from '@tanstack/react-router'
import { Toaster } from 'sonner'

export const Route = createRootRoute({
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
