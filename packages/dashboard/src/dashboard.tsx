import { AuthProvider, PermissionProvider, queryClient } from '@spree/dashboard-core'
import { ConfirmProvider, ThemeProvider, TooltipProvider } from '@spree/dashboard-ui'
import { QueryClientProvider } from '@tanstack/react-query'
import { type AnyRouter, RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'
// Side-effect bootstrap: i18next (base namespace + the app's resource
// bundle), the default sidebar nav, settings nav, and command-palette search
// entries. Importing this module runs them — before any chrome component
// reads the registries, and before plugin modules that call i18n.t at load.
import './i18n-setup'
import './nav/default'
import './nav/settings'
import './search/default'

/**
 * The Spree admin app shell: provider stack + router, fully wired.
 *
 * Hosts own the entry point, generate their route tree (via
 * `@spree/dashboard/vite` — shell routes + installed plugins' file routes),
 * and render this component:
 *
 *     // src/main.tsx
 *     import { createRoot } from 'react-dom/client'
 *     import { createDashboardRouter, Dashboard } from '@spree/dashboard'
 *     import 'virtual:spree-dashboard-plugins'  // activate installed plugins
 *     import './styles.css'
 *     import { routeTree } from './routeTree.gen'
 *
 *     const router = createDashboardRouter(routeTree)
 *
 *     declare module '@tanstack/react-router' {
 *       interface Register {
 *         router: typeof router
 *       }
 *     }
 *
 *     createRoot(document.getElementById('root')!).render(<Dashboard router={router} />)
 *
 * Import order matters: `@spree/dashboard` before the virtual plugin module,
 * so the i18n/nav bootstrap in this file runs before plugin registration.
 */
export function Dashboard({ router }: { router: AnyRouter }) {
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
