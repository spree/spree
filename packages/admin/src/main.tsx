import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { ConfirmProvider } from '@/components/spree/confirm-dialog'
import { TooltipProvider } from '@/components/ui/tooltip'
import { queryClient } from '@/lib/query-client'
import { AuthProvider } from '@/providers/auth-provider'
import { PermissionProvider } from '@/providers/permission-provider'
import { ThemeProvider } from '@/providers/theme-provider'
import { router } from '@/router'
import './index.css'

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
