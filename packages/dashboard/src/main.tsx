import { ConfirmProvider, TooltipProvider } from '@spree/dashboard-ui'
import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
// Side-effect imports: bootstrap i18next via dashboard-core (base namespace)
// and merge the app's resource bundle; register the app's nav and command-palette
// search entries against their registries. All must run before any chrome
// component reads from those registries — i.e. before @/router. (Plugin entries
// follow the same pattern.)
import '@/i18n-setup'
import '@/nav/default'
import '@/nav/settings'
import '@/search/default'
import { AuthProvider, PermissionProvider, queryClient } from '@spree/dashboard-core'
import { ThemeProvider } from '@spree/dashboard-ui'
import { router } from '@/router'
import '@/styles.css'

// Dev-only: run the reference plugin (packages/dashboard-plugin-example)
// against the real shell with VITE_EXAMPLE_PLUGIN=true. Keeps the example
// honest — its slots, routes, and table extensions render in a live
// dashboard instead of only existing on paper. Awaited so registration
// lands before the first render, same contract as any plugin import.
// Statically eliminated from production builds via the DEV guard.
if (import.meta.env.DEV && import.meta.env.VITE_EXAMPLE_PLUGIN === 'true') {
  await import('@spree/dashboard-plugin-example')
}

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
