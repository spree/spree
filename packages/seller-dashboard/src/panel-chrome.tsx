import {
  AppSidebar,
  MobileBreadcrumbBar,
  SettingsNavSheet,
  SettingsSidebar,
  StickyHeaderProvider,
  TenantProvider,
  TopBarUser,
  useAutoCollapseSidebar,
} from '@spree/dashboard-core'
import { SidebarInset, SidebarProvider, SidebarTrigger } from '@spree/dashboard-ui'
import { useParams, useRouterState } from '@tanstack/react-router'
import { type ReactNode, useState } from 'react'
import { SellerSwitcher } from './components/seller-switcher'

/**
 * The panel's frame: the sidebar and a content column under a top bar.
 *
 * The pieces are the operator dashboard's, not copies of them — `AppSidebar`
 * takes the tenant and its header as props precisely so a second panel can
 * reuse it, and the settings rail reads the same registry. A seller who has
 * used one recognises the other, and a fix to any of it reaches both.
 *
 * What the operator's chrome has that this does not is the command palette:
 * it needs a search surface this panel does not have yet, and mounting the
 * provider for an empty palette would be chrome that does nothing.
 */
export function PanelChrome({ children }: { children: ReactNode }) {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const inSettings = useRouterState({
    select: (state) => state.location.pathname.startsWith(`/${sellerId}/settings`),
  })

  return (
    // Scopes every shared query key to this seller, the way `StoreProvider`
    // does for the operator's dashboard — without it a cached list could
    // survive a switch and be shown under the next seller.
    <TenantProvider id={sellerId}>
      <StickyHeaderProvider>
        <SidebarProvider>
          <PanelShell sellerId={sellerId} inSettings={inSettings}>
            {children}
          </PanelShell>
        </SidebarProvider>
      </StickyHeaderProvider>
    </TenantProvider>
  )
}

/**
 * Inside `SidebarProvider` so it can drive the primary nav's collapsed state:
 * settings brings its own full-width rail, and two stacked columns leave the
 * content squeezed, so the primary one folds to icons for the duration.
 */
function PanelShell({
  sellerId,
  inSettings,
  children,
}: {
  sellerId: string
  inSettings: boolean
  children: ReactNode
}) {
  useAutoCollapseSidebar(inSettings)

  // Below `lg` the settings rail is hidden, so its sheet is the only way
  // between two settings pages. The trigger lives in the breadcrumb bar.
  const [settingsNavOpen, setSettingsNavOpen] = useState(false)

  return (
    <>
      <AppSidebar tenantId={sellerId} header={<SellerSwitcher />} />

      {/* `flex-row` so the settings rail sits flush against the primary
          sidebar and spans full height, as it does in the dashboard. */}
      <SidebarInset className="flex-row">
        <SettingsSidebar open={inSettings} tenantId={sellerId} />
        <div className="flex min-w-0 flex-1 flex-col">
          {/* The account menu carries sign-out, so the sidebar footer no
              longer does. */}
          {/* Matches the shared TopBar's contract: `sticky top-0` and exactly
              `header-height` tall. The table's pinned header offsets itself by
              that same variable, so a header of another height — or one that
              scrolls away — leaves the column titles floating mid-table. */}
          <header className="sticky top-0 z-40 flex h-header-height shrink-0 items-center gap-2 border-border-subtle border-b bg-background/90 px-4 backdrop-blur supports-[backdrop-filter]:bg-background/75">
            <SidebarTrigger />
            <div className="ml-auto flex items-center gap-2">
              <TopBarUser />
            </div>
          </header>

          <MobileBreadcrumbBar
            tenantId={sellerId}
            onOpenSettingsNav={() => setSettingsNavOpen(true)}
          />
          <SettingsNavSheet
            open={settingsNavOpen}
            onOpenChange={setSettingsNavOpen}
            tenantId={sellerId}
          />

          {/* Settings pages bring their own padding, matching the dashboard. */}
          {inSettings ? (
            children
          ) : (
            <div className="flex flex-1 flex-col gap-4 p-4 lg:p-6">{children}</div>
          )}
        </div>
      </SidebarInset>
    </>
  )
}
