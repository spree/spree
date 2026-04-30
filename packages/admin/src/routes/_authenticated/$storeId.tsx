import { createFileRoute, Outlet } from '@tanstack/react-router'
import { useEffect } from 'react'
import { adminClient } from '@/client'
import { AppSidebar } from '@/components/app-sidebar'
import { SidebarInset, SidebarProvider, SidebarTrigger } from '@/components/ui/sidebar'
import { StoreProvider } from '@/providers/store-provider'

export const Route = createFileRoute('/_authenticated/$storeId')({
  component: StoreLayout,
})

function StoreLayout() {
  const { storeId } = Route.useParams()

  useEffect(() => {
    adminClient.setStore(storeId)
  }, [storeId])

  return (
    <StoreProvider storeId={storeId}>
      <SidebarProvider>
        <AppSidebar />
        <SidebarInset>
          <header className="flex h-header-height shrink-0 items-center bg-white shadow-[inset_0_-1px_0_var(--color-border)]">
            <div className="flex items-center gap-2 px-4 h-header-height">
              <SidebarTrigger className="-ml-1 h-8 w-8" />
            </div>
          </header>
          <div className="container mx-auto flex flex-1 flex-col gap-4 p-4">
            <Outlet />
          </div>
        </SidebarInset>
      </SidebarProvider>
    </StoreProvider>
  )
}
