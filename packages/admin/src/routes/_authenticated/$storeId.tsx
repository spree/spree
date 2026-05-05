import { createFileRoute, Outlet } from '@tanstack/react-router'
import { useEffect } from 'react'
import { adminClient } from '@/client'
import { AppSidebar } from '@/components/spree/app-sidebar'
import { CommandPalette } from '@/components/spree/command-palette/command-palette'
import { TopBar } from '@/components/spree/top-bar'
import { SidebarInset, SidebarProvider } from '@/components/ui/sidebar'
import { CommandPaletteProvider } from '@/hooks/use-command-palette'
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
      <CommandPaletteProvider>
        <SidebarProvider>
          <AppSidebar />
          <SidebarInset>
            <TopBar />
            <div className="container mx-auto flex flex-1 flex-col gap-4 p-4">
              <Outlet />
            </div>
          </SidebarInset>
        </SidebarProvider>
        <CommandPalette />
      </CommandPaletteProvider>
    </StoreProvider>
  )
}
