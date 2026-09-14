import { AppShell, AppShellProvider, TenantProvider } from '@spree/dashboard-core'
import { useParams, useRouterState } from '@tanstack/react-router'
import { type ReactNode, useState } from 'react'
import { AccountDialog } from './components/account-dialog'
import { SellerSwitcher } from './components/seller-switcher'
import { getAvailableUiLocales } from './i18n'

// Derived once from the shipped locale bundles — stable for the panel's life.
const UI_LOCALES = getAvailableUiLocales()

/**
 * The panel's frame: the nav rail, and the page as a sheet beside it.
 *
 * The frame is the operator dashboard's, not a copy of it — `AppShell` takes
 * the tenant and its sidebar header as props precisely so a second panel can
 * mount it. A seller who has used one recognises the other, and a fix to any
 * of it reaches both.
 *
 * What the operator's chrome has that this does not is the command palette: it
 * needs a search surface this panel does not have yet, so no provider is
 * mounted and the rail's search affordance hides itself accordingly.
 */
export function PanelChrome({ children }: { children: ReactNode }) {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const inSettings = useRouterState({
    select: (state) => state.location.pathname.startsWith(`/${sellerId}/settings`),
  })
  // The account is edited in a dialog rather than on a page, so the frame owns
  // its open state — the trigger sits in the sidebar's account menu, which is
  // mounted here and stays put across route changes.
  const [accountOpen, setAccountOpen] = useState(false)

  return (
    // Scopes every shared query key to this seller, the way `StoreProvider`
    // does for the operator's dashboard — without it a cached list could
    // survive a switch and be shown under the next seller.
    <TenantProvider id={sellerId}>
      <AppShellProvider>
        <AppShell
          tenantId={sellerId}
          sidebarHeader={<SellerSwitcher />}
          inSettings={inSettings}
          uiLocales={UI_LOCALES}
          onEditProfile={() => setAccountOpen(true)}
        >
          <AccountDialog open={accountOpen} onOpenChange={setAccountOpen} />
          {children}
        </AppShell>
      </AppShellProvider>
    </TenantProvider>
  )
}
