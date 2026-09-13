import {
  AppShell,
  AppShellProvider,
  adminClient,
  CommandPaletteProvider,
  StoreProvider,
} from '@spree/dashboard-core'
import { createFileRoute, Outlet, useRouterState } from '@tanstack/react-router'
import { useState } from 'react'
import { CommandPalette } from '../../components/spree/command-palette/command-palette'
import { ProfileDialog } from '../../components/spree/profile-dialog'
import { useDashboardCounters } from '../../hooks/use-dashboard-counters'
import { getAvailableUiLocales } from '../../i18n-setup'

// Derived once from the shipped locale bundles — stable for the app lifetime.
const UI_LOCALES = getAvailableUiLocales()

export const Route = createFileRoute('/_authenticated/$storeId')({
  // The X-Spree-Store-Id header must be set before ANY query under this route
  // fires — child effects (where React Query starts fetches) run before a
  // parent effect would, so an effect here is too late and the first fetch
  // after a store switch would carry the previous store's header.
  beforeLoad: ({ params }) => {
    adminClient.setStore(params.storeId)
  },
  component: StoreLayout,
})

function StoreLayout() {
  const { storeId } = Route.useParams()
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const inSettings = pathname.startsWith(`/${storeId}/settings`)
  // Permissions are store-scoped (roles are held per store), and the provider
  // now keys its query by the active store — so switching store refetches them
  // on its own. The manual reload this used to run here is not just redundant
  // but harmful: it re-ran whenever its callback changed identity.

  return (
    <StoreProvider storeId={storeId}>
      <CommandPaletteProvider>
        <AppShellProvider>
          <StoreShell inSettings={inSettings} />
        </AppShellProvider>
        <CommandPalette />
      </CommandPaletteProvider>
    </StoreProvider>
  )
}

function StoreShell({ inSettings }: { inSettings: boolean }) {
  // Loaded by the shell rather than by whichever badge happens to be on screen:
  // the sidebar only mounts the children of the section you are in, so leaving
  // the request to a badge means no counts at all on every other page. One
  // query key, so the badges and the home screen's card share this one request.
  useDashboardCounters()
  // The profile is edited in a dialog rather than a page, so the shell owns its
  // open state — the trigger sits in the sidebar's account menu, which is
  // mounted here and stays put across route changes.
  const [profileOpen, setProfileOpen] = useState(false)

  return (
    <AppShell
      inSettings={inSettings}
      uiLocales={UI_LOCALES}
      onEditProfile={() => setProfileOpen(true)}
    >
      <ProfileDialog open={profileOpen} onOpenChange={setProfileOpen} />
      <Outlet />
    </AppShell>
  )
}
