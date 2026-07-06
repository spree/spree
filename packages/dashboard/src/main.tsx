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
// Activate installed dashboard plugins. The module is synthesized by
// `spreeDashboardPlugin()` in vite.config.ts from the auto-discovered plugin
// list (package.json deps carrying the `spree.dashboard.plugin` marker) —
// installing a plugin needs no edit here. Must come after '@/i18n-setup' so
// plugins can call i18n.t at module load.
import 'virtual:spree-dashboard-plugins'
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
