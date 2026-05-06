import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode, useEffect } from 'react'
import { createRoot } from 'react-dom/client'
import { ConfirmProvider } from '@/components/spree/confirm-dialog'
import { TooltipProvider } from '@/components/ui/tooltip'
import { useAuth } from '@/hooks/use-auth'
import { queryClient } from '@/lib/query-client'
import { AuthProvider } from '@/providers/auth-provider'
import { PermissionProvider, usePermissions } from '@/providers/permission-provider'
import { router } from '@/router'
import './index.css'

function InnerApp() {
  const auth = useAuth()
  const { permissions } = usePermissions()

  // beforeLoad guards capture the auth context at navigation time. When the
  // bootstrap settles or auth changes (login/logout), invalidate the router so
  // the guards re-run with the fresh context — otherwise the user gets stuck
  // on a route that doesn't match their new auth state.
  useEffect(() => {
    router.invalidate()
  }, [auth.isAuthenticated, auth.isInitializing])

  return <RouterProvider router={router} context={{ auth, permissions }} />
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <PermissionProvider>
          <TooltipProvider>
            <ConfirmProvider>
              <InnerApp />
            </ConfirmProvider>
          </TooltipProvider>
        </PermissionProvider>
      </AuthProvider>
    </QueryClientProvider>
  </StrictMode>,
)
