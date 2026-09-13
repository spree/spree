import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarHeader,
  SidebarMenu,
  SidebarMenuItem,
  SidebarTrigger,
  Skeleton,
  useSidebar,
} from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import { useParams } from '@tanstack/react-router'
import type { ComponentProps, ReactNode } from 'react'
import { useAuth } from '../hooks/use-auth'
import { primarySidebarSide, useTranslation } from '../lib/i18n'
import { type NavEntry, resolveNavLabel, useNavEntries } from '../lib/nav-registry'
import type { ActionName, SubjectName } from '../lib/permissions'
import { type Permissions, usePermissions } from '../providers/permission-provider'
import { useOptionalStore } from '../providers/store-provider'
import { type NavItem, NavMain } from './nav-main'
import { SidebarSearch } from './sidebar-search'
import { SidebarUser } from './sidebar-user'
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
  const allowed = (entry: { subject?: SubjectName; action?: ActionName }) =>
    !entry.subject || permissions.can(entry.action ?? 'read', entry.subject)

  return (
    items
      .filter(allowed)
      .map((item) => ({
        ...item,
        items: item.items?.filter(allowed),
      }))
      // A group that declares no subject of its own is gated by its children —
      // it has no page to land on, so once every child is filtered out the
      // group would link somewhere the role cannot open.
      .filter((item) => item.subject || !item.items || item.items.length > 0)
  )
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
export function useNavItems(tenantId: string): {
  navItems: NavItem[]
  bottomItems: NavItem[]
  /** True while permissions are still loading, so the nav is not yet knowable. */
  isLoading: boolean
} {
  const { t } = useTranslation()
  const { permissions, isLoading } = usePermissions()
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

  return { navItems, bottomItems, isLoading }
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
 *
 * The rail carries the whole of the app's chrome: the tenant switcher and
 * search above the nav, the account menu at its foot. There is no top bar —
 * the page's own header is the only thing above the content.
 */
export function AppSidebar({
  tenantId,
  header,
  uiLocales,
  onEditProfile,
  ...props
}: ComponentProps<typeof Sidebar> & {
  /**
   * The id the nav links are prefixed with. Defaults to the route's `storeId`,
   * so the operator's dashboard passes nothing.
   */
  tenantId?: string
  /** Rendered in the header. Defaults to the store switcher. */
  header?: ReactNode
  /** Admin UI languages offered by the account menu's language switcher. */
  uiLocales?: ReadonlyArray<{ code: string; name: string }>
  /** Opens the app's edit-profile dialog from the account menu. */
  onEditProfile?: () => void
}) {
  const { i18n } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const { navItems, bottomItems, isLoading } = useNavItems(tenantId ?? storeId ?? 'default')

  return (
    <Sidebar collapsible="icon" variant="inset" side={primarySidebarSide(i18n.language)} {...props}>
      <SidebarHeader>
        {/* The switcher, search and the account row are all hidden on a phone:
            the top bar already names the store and carries both search and the
            account menu, so repeating them inside the drawer spends rows of a
            small screen saying what is visible behind it. The drawer is for
            navigating. */}
        <div className="hidden items-center gap-1 md:flex">
          <div className="min-w-0 flex-1">{header ?? <StoreSwitcher />}</div>
          <CollapseTrigger />
        </div>
        <div className="hidden md:block">
          <SidebarSearch />
        </div>
      </SidebarHeader>
      <SidebarContent>
        {/* Permissions decide which links exist, and until they arrive every
            `can()` answers false — so the real nav is not "empty", it is not
            yet known. Rendering the filtered list during that window shows a
            near-empty rail that then pops to a full one; skeleton rows keep the
            shell's shape steady and say the difference honestly.

            Keyed on `isLoading` alone, not on an empty list: entries without a
            `subject` (Home, Getting Started) skip the permission filter, so the
            list is never actually empty and a length check would never fire. */}
        {isLoading ? <NavSkeleton /> : <NavMain items={navItems} bottomItems={bottomItems} />}
      </SidebarContent>
      <SidebarFooter className="hidden md:flex">
        <SidebarUser uiLocales={uiLocales} onEditProfile={onEditProfile} />
      </SidebarFooter>
    </Sidebar>
  )
}

/**
 * Placeholder rows for the primary nav while permissions load.
 *
 * The count is deliberate rather than arbitrary: it approximates a typical
 * operator's nav so the rail does not visibly resize when the real list
 * replaces it. Marked `aria-hidden` — a screen reader gains nothing from
 * placeholder rows, and the shell announces the page itself.
 */
function NavSkeleton() {
  return (
    <SidebarGroup aria-hidden>
      <SidebarMenu>
        {Array.from({ length: 8 }, (_, i) => (
          // biome-ignore lint/suspicious/noArrayIndexKey: fixed-length placeholder list
          <SidebarMenuItem key={i}>
            <div className="flex h-8 items-center gap-2 px-2">
              <Skeleton className="size-4 shrink-0 rounded" />
              <Skeleton className="h-3 w-24 group-data-[collapsible=icon]:hidden" />
            </div>
          </SidebarMenuItem>
        ))}
      </SidebarMenu>
    </SidebarGroup>
  )
}

/**
 * Collapses the rail to its icon width, beside the tenant switcher.
 *
 * It lives here because the rail is now the app's only chrome — the top bar
 * that used to carry this control is gone, and without it the rail could be
 * collapsed by keyboard alone. Hidden once collapsed: at icon width there is
 * no room beside the avatar, and the rail's own edge handle (`SidebarRail`)
 * expands it again.
 */
function CollapseTrigger() {
  const { isMobile, state } = useSidebar()
  if (isMobile || state === 'collapsed') return null

  return (
    <SidebarTrigger className="shrink-0 text-muted-foreground hover:bg-sidebar-accent hover:text-foreground" />
  )
}
