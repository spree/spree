import { createFileRoute, Outlet, redirect } from '@tanstack/react-router'

export const Route = createFileRoute('/_authenticated')({
  beforeLoad: ({ context }) => {
    // Wait for the cold-load `/auth/refresh` bootstrap before deciding to redirect —
    // otherwise an authenticated user with a valid refresh cookie would be bounced
    // to /login during the first render pass.
    if (context.auth.isInitializing) return
    if (!context.auth.isAuthenticated) {
      throw redirect({ to: '/login' })
    }
  },
  component: AuthenticatedLayout,
})

function AuthenticatedLayout() {
  return <Outlet />
}
