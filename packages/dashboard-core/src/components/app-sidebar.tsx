import { Sidebar, SidebarContent, SidebarHeader } from '@spree/dashboard-ui'
import { useParams } from '@tanstack/react-router'
import { PackageIcon } from 'lucide-react'
import type { ComponentProps } from 'react'
import { useAuth } from '../hooks/use-auth'
import { primarySidebarSide, useTranslation } from '../lib/i18n'
import { type NavEntry, useNavEntries } from '../lib/nav-registry'
import { type Permissions, usePermissions } from '../providers/permission-provider'
import { useStore } from '../providers/store-provider'
import { type NavItem, NavMain } from './nav-main'
import { StoreSwitcher } from './store-switcher'

function entryToNavItem(entry: NavEntry, storeId: string): NavItem {
  const pathFor = (path: string) => (path === '/' ? `/${storeId}` : `/${storeId}${path}`)
  return {
    title: entry.label,
    url: pathFor(entry.path),
    icon: entry.icon ?? PackageIcon,
    subject: entry.subject,
    badge: entry.badge,
    items: entry.children?.map((child) => ({
      title: child.label,
      url: pathFor(child.path),
      subject: child.subject,
    })),
  }
}

/** Hide items the user can't `read`. */
function filterByPermissions(items: NavItem[], permissions: Permissions): NavItem[] {
  return items
    .filter((item) => !item.subject || permissions.can('read', item.subject))
    .map((item) => ({
      ...item,
      items: item.items?.filter((sub) => !sub.subject || permissions.can('read', sub.subject)),
    }))
}

export function AppSidebar(props: ComponentProps<typeof Sidebar>) {
  const { i18n } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const { permissions } = usePermissions()
  const { store } = useStore()
  const { user } = useAuth()
  const id = storeId || 'default'
  const { main, bottom } = useNavEntries()

  const visibilityContext = { permissions, store, user }
  const visible = (entry: NavEntry) => !entry.if || entry.if(visibilityContext)

  const navItems = filterByPermissions(
    main.filter(visible).map((e) => entryToNavItem(e, id)),
    permissions,
  )
  const bottomItems = filterByPermissions(
    bottom.filter(visible).map((e) => entryToNavItem(e, id)),
    permissions,
  )

  return (
    <Sidebar collapsible="icon" side={primarySidebarSide(i18n.language)} {...props}>
      <SidebarHeader>
        <StoreSwitcher />
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navItems} bottomItems={bottomItems} />
      </SidebarContent>
    </Sidebar>
  )
}
