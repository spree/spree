import { NavMain, StickyHeaderProvider, TopBarUser, useNavItems } from '@spree/dashboard-core'
import {
  Sidebar,
  SidebarContent,
  SidebarHeader,
  SidebarInset,
  SidebarProvider,
  SidebarTrigger,
} from '@spree/dashboard-ui'
import { useParams } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { SellerSwitcher } from './components/seller-switcher'

/**
 * The panel's frame: the sidebar and a content column under a top bar.
 *
 * Built on the same primitives, the same nav registry and the same account
 * menu as the operator's dashboard, so a seller who has used one recognises
 * the other and a fix to the shared pieces reaches both.
 *
 * The store switcher's counterpart is the seller switcher in the header.
 * What the operator's chrome has that this does not: a settings sub-shell,
 * and the command palette — the latter needs a search surface this panel does
 * not have yet, and mounting the provider for an empty palette would be
 * chrome that does nothing.
 */
export function PanelChrome({ children }: { children: ReactNode }) {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const { navItems, bottomItems } = useNavItems(sellerId)

  return (
    <StickyHeaderProvider>
      <SidebarProvider>
        <Sidebar collapsible="icon">
          <SidebarHeader>
            <SellerSwitcher />
          </SidebarHeader>
          <SidebarContent>
            <NavMain items={navItems} bottomItems={bottomItems} />
          </SidebarContent>
        </Sidebar>

        <SidebarInset>
          {/* The account menu carries sign-out, so the sidebar footer no
              longer does. */}
          <header className="flex h-14 shrink-0 items-center gap-2 border-border-subtle border-b px-4">
            <SidebarTrigger />
            <div className="ml-auto flex items-center gap-2">
              <TopBarUser />
            </div>
          </header>

          <div className="flex flex-1 flex-col gap-4 p-4 lg:p-6">{children}</div>
        </SidebarInset>
      </SidebarProvider>
    </StickyHeaderProvider>
  )
}
