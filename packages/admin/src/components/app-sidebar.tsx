import { useParams } from '@tanstack/react-router'
import { PackageIcon } from 'lucide-react'
import type { ComponentProps } from 'react'
import { type NavItem, NavMain } from '@/components/nav-main'
import { NavUser } from '@/components/nav-user'
import { StoreSwitcher } from '@/components/store-switcher'
import { Sidebar, SidebarContent, SidebarFooter, SidebarHeader } from '@/components/ui/sidebar'
import { type NavEntry, useNavEntries } from '@/lib/nav-registry'
import { type Permissions, usePermissions } from '@/providers/permission-provider'

import '@/nav/default'

function entryToNavItem(entry: NavEntry, storeId: string): NavItem {
  const pathFor = (path: string) => (path === '/' ? `/${storeId}` : `/${storeId}${path}`)
  return {
    title: entry.label,
    url: pathFor(entry.path),
    icon: entry.icon ?? PackageIcon,
    subject: entry.subject,
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
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const { permissions } = usePermissions()
  const id = storeId || 'default'
  const { main, bottom } = useNavEntries()

  const navItems = filterByPermissions(
    main.map((e) => entryToNavItem(e, id)),
    permissions,
  )
  const bottomItems = filterByPermissions(
    bottom.map((e) => entryToNavItem(e, id)),
    permissions,
  )

  return (
    <Sidebar collapsible="icon" {...props}>
      <SidebarHeader>
        <StoreSwitcher />
      </SidebarHeader>
      <SidebarContent>
        <NavMain items={navItems} bottomItems={bottomItems} />
      </SidebarContent>
      <SidebarFooter>
        <NavUser />
      </SidebarFooter>
    </Sidebar>
  )
}
