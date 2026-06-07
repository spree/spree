import { ConfirmProvider, TooltipProvider } from '@spree/dashboard-ui'
import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
// Side-effect imports: bootstrap i18next via dashboard-core (base namespace)
// and merge the app's resource bundle; register the app's nav entries against
// the nav-registry. Both must run before any chrome component reads from those
// registries — i.e. before @/router. (Plugin entries follow the same pattern.)
import '@/i18n-setup'
import '@/nav/default'
import '@/nav/settings'
import { AuthProvider, PermissionProvider, queryClient } from '@spree/dashboard-core'
import { ThemeProvider } from '@spree/dashboard-ui'
import { router } from '@/router'
import '@/styles.css'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <ThemeProvider>
        <AuthProvider>
          <PermissionProvider>
            <TooltipProvider>
              <ConfirmProvider>
                <RouterProvider router={router} />
              </ConfirmProvider>
            </TooltipProvider>
          </PermissionProvider>
        </AuthProvider>
      </ThemeProvider>
    </QueryClientProvider>
  </StrictMode>,
)
// test
// re-test with full output
