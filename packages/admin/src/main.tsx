import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClientProvider } from '@tanstack/react-query'
import { RouterProvider } from '@tanstack/react-router'
import { TooltipProvider } from '@/components/ui/tooltip'
import { AuthProvider } from '@/providers/auth-provider'
import { useAuth } from '@/hooks/use-auth'
import { queryClient } from '@/lib/query-client'
import { router } from '@/router'
import './index.css'

function InnerApp() {
  const auth = useAuth()
  return <RouterProvider router={router} context={{ auth }} />
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <TooltipProvider>
          <InnerApp />
        </TooltipProvider>
      </AuthProvider>
    </QueryClientProvider>
  </StrictMode>,
)
