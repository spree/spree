import { AuthProvider, PermissionProvider, queryClient } from '@spree/dashboard-core'
import { ConfirmProvider, ThemeProvider, TooltipProvider } from '@spree/dashboard-ui'
import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
// Side-effect bootstrap: i18next (base namespace + the app's resource
// bundle), the default sidebar nav, settings nav, and command-palette search
// entries. Importing this module runs them — before any chrome component
// reads the registries, and before plugin modules that call i18n.t at load.
import './i18n-setup'
import './nav/default'
import './nav/settings'
import './search/default'
import { router } from './router'

/**
 * The Spree admin app shell: provider stack + router, fully wired.
 *
 * Hosts own the entry point and render this component:
 *
 *     // src/main.tsx
 *     import { createRoot } from 'react-dom/client'
 *     import { Dashboard } from '@spree/dashboard'
 *     import 'virtual:spree-dashboard-plugins'  // activate installed plugins
 *     import './styles.css'
 *
 *     createRoot(document.getElementById('root')!).render(<Dashboard />)
 *
 * Import order matters: `@spree/dashboard` before the virtual plugin module,
 * so the i18n/nav bootstrap in this file runs before plugin registration.
 * Requires `spreeDashboardPlugin()` (from `@spree/dashboard/vite`) in the
 * host's Vite config — it serves the virtual module and wires Tailwind.
 */
export function Dashboard() {
  return (
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
    </StrictMode>
  )
}
