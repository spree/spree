import { Sidebar, SidebarContent, SidebarHeader } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import { useParams } from '@tanstack/react-router'
import type { ComponentProps, ReactNode } from 'react'
import { useAuth } from '../hooks/use-auth'
import { primarySidebarSide, useTranslation } from '../lib/i18n'
import { type NavEntry, resolveNavLabel, useNavEntries } from '../lib/nav-registry'
import { type Permissions, usePermissions } from '../providers/permission-provider'
import { useOptionalStore } from '../providers/store-provider'
import { type NavItem, NavMain } from './nav-main'
import { StoreSwitcher } from './store-switcher'

/**
 * `labelKey` is resolved here rather than at registration so labels follow a
 * language change — a literal `label` is frozen at import time.
 */
function entryToNavItem(entry: NavEntry, tenantId: string, t: (key: string) => string): NavItem {
  const pathFor = (path: string) => (path === '/' ? `/${tenantId}` : `/${tenantId}${path}`)
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

/**
 * The nav registry resolved for one tenant: entries prefixed with the tenant
 * segment, `if` gates evaluated, and items the user cannot act on removed.
 *
 * Exported so a panel scoped by something other than a store composes the
 * same registry — the seller panel prefixes with a seller id instead — rather
 * than re-deriving the prefixing and permission filtering, which is what a
 * second sidebar would otherwise copy.
 */
export function useNavItems(tenantId: string): { navItems: NavItem[]; bottomItems: NavItem[] } {
  const { t } = useTranslation()
  const { permissions } = usePermissions()
  const store = useOptionalStore()?.store ?? null
  const { user } = useAuth()
  const { main, bottom } = useNavEntries()

  const visibilityContext = { permissions, store, user }
  const visible = (entry: NavEntry) => !entry.if || entry.if(visibilityContext)

  const navItems = filterByPermissions(
    main.filter(visible).map((e) => entryToNavItem(e, tenantId, t)),
    permissions,
  )
  const bottomItems = filterByPermissions(
    bottom.filter(visible).map((e) => entryToNavItem(e, tenantId, t)),
    permissions,
  )

  return { navItems, bottomItems }
}

/**
 * The primary sidebar: registry-driven nav under a tenant switcher.
 *
 * Shared by every panel. The two things that genuinely differ are which
 * tenant the links are built under and what sits in the header — a store
 * switcher for the operator, a seller switcher for the marketplace panel — so
 * both are props. Everything else (side-by-language, collapsible rail,
 * permission filtering) is the same in either, and a panel that copied this to
 * change the header would silently miss every later fix to the rest.
 */
export function AppSidebar({
  tenantId,
  header,
  ...props
}: ComponentProps<typeof Sidebar> & {
  /**
   * The id the nav links are prefixed with. Defaults to the route's `storeId`,
   * so the operator's dashboard passes nothing.
   */
  tenantId?: string
  /** Rendered in the header. Defaults to the store switcher. */
  header?: ReactNode
}) {
  const { i18n } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const { navItems, bottomItems } = useNavItems(tenantId ?? storeId ?? 'default')

  return (
    <Sidebar collapsible="icon" side={primarySidebarSide(i18n.language)} {...props}>
      <SidebarHeader>{header ?? <StoreSwitcher />}</SidebarHeader>
      <SidebarContent>
        <NavMain items={navItems} bottomItems={bottomItems} />
      </SidebarContent>
    </Sidebar>
  )
}
