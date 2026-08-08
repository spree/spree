import {
  AppSidebar,
  adminClient,
  CommandPaletteProvider,
  SettingsSidebar,
  StickyHeaderProvider,
  StoreProvider,
  TopBar,
  useAutoCollapseSidebar,
} from '@spree/dashboard-core'
import { SidebarInset, SidebarProvider } from '@spree/dashboard-ui'
import { createFileRoute, Outlet, useRouterState } from '@tanstack/react-router'
import { useEffect, useState } from 'react'
import { CommandPalette } from '../../components/spree/command-palette/command-palette'
import { ProfileDialog } from '../../components/spree/profile-dialog'
import { getAvailableUiLocales } from '../../i18n-setup'

// Derived once from the shipped locale bundles — stable for the app lifetime.
const UI_LOCALES = getAvailableUiLocales()

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
        <StickyHeaderProvider>
          <SidebarProvider>
            <StoreShell inSettings={inSettings} />
          </SidebarProvider>
          <CommandPalette />
        </StickyHeaderProvider>
      </CommandPaletteProvider>
    </StoreProvider>
  )
}

/**
 * Inside `SidebarProvider` so it can drive the primary nav's collapsed state:
 * the settings area brings its own full-width nav, so the primary one folds to
 * icons while the merchant is in there.
 */
function StoreShell({ inSettings }: { inSettings: boolean }) {
  useAutoCollapseSidebar(inSettings)
  // The profile is edited in a dialog rather than a page, so the shell owns its
  // open state — the trigger sits in the TopBar's user menu, which is mounted
  // here and stays put across route changes.
  const [profileOpen, setProfileOpen] = useState(false)

  return (
    <>
      <AppSidebar />
      {/* `flex-row` so the secondary sidebar can sit flush against the
          primary and span full height. The TopBar moves into the content
          column so the secondary sidebar can extend above it. */}
      <SidebarInset className="flex-row">
        <SettingsSidebar open={inSettings} />
        <div className="flex min-w-0 flex-1 flex-col">
          <TopBar uiLocales={UI_LOCALES} onEditProfile={() => setProfileOpen(true)} />
          <ProfileDialog open={profileOpen} onOpenChange={setProfileOpen} />
          {inSettings ? (
            <Outlet />
          ) : (
            <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">
              <Outlet />
            </div>
          )}
        </div>
      </SidebarInset>
    </>
  )
}
