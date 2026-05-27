import { createFileRoute, Outlet, useRouterState } from '@tanstack/react-router'
import { useEffect } from 'react'
import { adminClient } from '@/client'
import { AppSidebar } from '@/components/spree/app-sidebar'
import { CommandPalette } from '@/components/spree/command-palette/command-palette'
import { SettingsSidebar } from '@/components/spree/settings-sidebar'
import { TopBar } from '@/components/spree/top-bar'
import { SidebarInset, SidebarProvider } from '@/components/ui/sidebar'
import { CommandPaletteProvider } from '@/hooks/use-command-palette'
import { StoreProvider } from '@/providers/store-provider'

export const Route = createFileRoute('/_authenticated/$storeId')({
  component: StoreLayout,
})

function StoreLayout() {
  const { storeId } = Route.useParams()
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const inSettings = pathname.startsWith(`/${storeId}/settings`)

  useEffect(() => {
    adminClient.setStore(storeId)
  }, [storeId])

  return (
    <StoreProvider storeId={storeId}>
      <CommandPaletteProvider>
        <SidebarProvider>
          <AppSidebar />
          {/* `flex-row` so the secondary sidebar can sit flush against the
              primary and span full height. The TopBar moves into the content
              column so the secondary sidebar can extend above it. */}
          <SidebarInset className="flex-row">
            <SettingsSidebar open={inSettings} />
            <div className="flex min-w-0 flex-1 flex-col">
              <TopBar />
              {inSettings ? (
                <Outlet />
              ) : (
                <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">
                  <Outlet />
                </div>
              )}
            </div>
          </SidebarInset>
        </SidebarProvider>
        <CommandPalette />
      </CommandPaletteProvider>
    </StoreProvider>
  )
}
