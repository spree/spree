import { ConfirmProvider, TooltipProvider } from '@spree/dashboard-ui'
import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
// Side-effect import: registers i18next with react-i18next before any component
// calls useTranslation(). Must come before @/router.
import '@/lib/i18n'
import { queryClient } from '@/lib/query-client'
import { AuthProvider } from '@/providers/auth-provider'
import { PermissionProvider } from '@/providers/permission-provider'
import { ThemeProvider } from '@/providers/theme-provider'
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
