import { NavMain, useAuth, useNavItems } from '@spree/dashboard-core'
import {
  Button,
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarHeader,
  SidebarInset,
  SidebarProvider,
} from '@spree/dashboard-ui'
import { Link, useParams } from '@tanstack/react-router'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * The panel's frame: the sidebar and a content column.
 *
 * Built on the same sidebar primitives and the same nav registry as the
 * operator's dashboard, so a marketplace customises this panel the way it
 * customises that one — `defineDashboardPlugin({ nav, slots, ... })` — rather
 * than forking the chrome. `useNavItems` resolves the registry against the
 * seller id: entries are prefixed with it, `if` gates evaluated, and items the
 * member cannot act on hidden by the same permission filter.
 *
 * Deliberately without the operator's store switcher, settings sidebar and
 * command palette. A seller has one tenant at a time (switching is a link
 * back to the picker) and nothing here yet earns a palette.
 */
export function PanelChrome({ children }: { children: ReactNode }) {
  const { t } = useTranslation()
  const { logout } = useAuth()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const { navItems, bottomItems } = useNavItems(sellerId)

  return (
    <SidebarProvider>
      <Sidebar collapsible="icon">
        <SidebarHeader className="px-4 py-3">
          <p className="truncate font-medium text-sm">{t('app.name')}</p>
        </SidebarHeader>
        <SidebarContent>
          <NavMain items={navItems} bottomItems={bottomItems} />
        </SidebarContent>
        <SidebarFooter className="flex flex-col gap-1 p-2">
          <Button variant="ghost" size="sm" className="justify-start" asChild>
            <Link to="/">{t('seller_picker.title')}</Link>
          </Button>
          <Button variant="ghost" size="sm" className="justify-start" onClick={() => logout()}>
            {t('nav.sign_out')}
          </Button>
        </SidebarFooter>
      </Sidebar>

      <SidebarInset>
        <div className="container mx-auto flex flex-1 flex-col gap-4 p-4 lg:p-6">{children}</div>
      </SidebarInset>
    </SidebarProvider>
  )
}
