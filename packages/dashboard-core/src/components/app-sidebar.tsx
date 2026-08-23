import { Sidebar, SidebarContent, SidebarHeader } from '@spree/dashboard-ui'
import { useParams } from '@tanstack/react-router'
import { PackageIcon } from 'lucide-react'
import type { ComponentProps } from 'react'
import { useAuth } from '../hooks/use-auth'
import { primarySidebarSide, useTranslation } from '../lib/i18n'
import { type NavEntry, resolveNavLabel, useNavEntries } from '../lib/nav-registry'
import { type Permissions, usePermissions } from '../providers/permission-provider'
import { useStore } from '../providers/store-provider'
import { type NavItem, NavMain } from './nav-main'
import { StoreSwitcher } from './store-switcher'

/**
 * `labelKey` is resolved here rather than at registration so labels follow a
 * language change — a literal `label` is frozen at import time.
 */
function entryToNavItem(entry: NavEntry, storeId: string, t: (key: string) => string): NavItem {
  const pathFor = (path: string) => (path === '/' ? `/${storeId}` : `/${storeId}${path}`)
  return {
    title: resolveNavLabel(entry, t),
    url: pathFor(entry.path),
    icon: entry.icon ?? PackageIcon,
    subject: entry.subject,
    action: entry.action,
    badge: entry.badge,
    items: entry.children?.map((child) => ({
      title: resolveNavLabel(child, t),
      url: pathFor(child.path),
      subject: child.subject,
      action: child.action,
      badge: child.badge,
    })),
  }
}

/** Hide items the user can't act on — `read` unless the entry says otherwise. */
function filterByPermissions(items: NavItem[], permissions: Permissions): NavItem[] {
  return items
    .filter((item) => !item.subject || permissions.can(item.action ?? 'read', item.subject))
    .map((item) => ({
      ...item,
      items: item.items?.filter(
        (sub) => !sub.subject || permissions.can(sub.action ?? 'read', sub.subject),
      ),
    }))
}

export function AppSidebar(props: ComponentProps<typeof Sidebar>) {
  const { t, i18n } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const { permissions } = usePermissions()
  const { store } = useStore()
  const { user } = useAuth()
  const id = storeId || 'default'
  const { main, bottom } = useNavEntries()

  const visibilityContext = { permissions, store, user }
  const visible = (entry: NavEntry) => !entry.if || entry.if(visibilityContext)

  const navItems = filterByPermissions(
    main.filter(visible).map((e) => entryToNavItem(e, id, t)),
    permissions,
  )
  const bottomItems = filterByPermissions(
    bottom.filter(visible).map((e) => entryToNavItem(e, id, t)),
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
