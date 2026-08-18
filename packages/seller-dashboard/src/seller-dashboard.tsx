import { AuthProvider, PermissionProvider, queryClient } from '@spree/dashboard-core'
import { ConfirmProvider, ThemeProvider, TooltipProvider } from '@spree/dashboard-ui'
import { QueryClientProvider } from '@tanstack/react-query'
import type { AnyRouter } from '@tanstack/react-router'
import { RouterProvider } from '@tanstack/react-router'
import { StrictMode } from 'react'

/**
 * The seller panel shell.
 *
 * The same providers as the marketplace operator's dashboard — that is what
 * `@spree/dashboard-core` and `@spree/dashboard-ui` are for — pointed at the
 * Seller API. The host registers that client before rendering:
 *
 *     // src/main.tsx
 *     import { createRoot } from 'react-dom/client'
 *     import { SellerDashboard, createSellerRouter } from '@spree/seller-dashboard'
 *     import './api-client'   // registers the Seller API client
 *     import './styles.css'
 *     import { routeTree } from './routeTree.gen'
 *
 *     const router = createSellerRouter(routeTree)
 *
 *     declare module '@tanstack/react-router' {
 *       interface Register {
 *         router: typeof router
 *       }
 *     }
 *
 *     createRoot(document.getElementById('root')!).render(<SellerDashboard router={router} />)
 */
export function SellerDashboard({ router }: { router: AnyRouter }) {
  return (
    <StrictMode>
      <QueryClientProvider client={queryClient}>
        <ThemeProvider>
          <TooltipProvider>
            <ConfirmProvider>
              <AuthProvider>
                <PermissionProvider>
                  <RouterProvider router={router} />
                </PermissionProvider>
              </AuthProvider>
            </ConfirmProvider>
          </TooltipProvider>
        </ThemeProvider>
      </QueryClientProvider>
    </StrictMode>
  )
}
