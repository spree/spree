import { ConfirmProvider, TooltipProvider } from '@spree/dashboard-ui'
import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
// Side-effect import: bootstraps i18next via dashboard-core (base namespace)
// and merges the app's resource bundle. Must run before any component calls
// useTranslation() — i.e. before @/router.
import '@/i18n-setup'
import { AuthProvider, PermissionProvider, queryClient } from '@spree/dashboard-core'
import { ThemeProvider } from '@spree/dashboard-ui'
import { router } from '@/router'
import '@spree/dashboard-ui/styles.css'

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
