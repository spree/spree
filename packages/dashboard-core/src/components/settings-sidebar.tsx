import {
  Badge,
  cn,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from '@spree/dashboard-ui'
import { Link, useParams, useRouterState } from '@tanstack/react-router'
import { PackageIcon } from 'lucide-react'
import { useTranslation } from 'react-i18next'
import {
  type SettingsNavEntry,
  type SettingsNavSnapshot,
  useSettingsNav,
} from '../lib/settings-nav-registry'
import { type Permissions, usePermissions } from '../providers/permission-provider'
import { NavIcon } from './nav-main'

/**
 * Secondary settings sidebar. Always mounted as a sibling to the primary
 * sidebar so it can extend full-height (top of viewport to bottom, beside
 * the TopBar rather than below it). Width animates between `0` and
 * `--spacing-sidebar-width` driven by the `open` prop, so entering and
 * leaving the settings area gets a slide-in/slide-out transition.
 *
 * Entries reuse the same shadcn primitives (`SidebarMenuButton`, `NavIcon`,
 * `SidebarGroupLabel`) as the primary sidebar so hover/active states and
 * spacing stay perfectly consistent.
 *
 * Hidden below `lg` regardless of `open` — settings on narrow viewports
 * still need a separate solution.
 */
export function SettingsSidebar({ open }: { open: boolean }) {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const id = storeId ?? 'default'
  const snapshot = useSettingsNav()
  const { permissions } = usePermissions()
  const visible = filterByPermissions(snapshot, permissions)

  // `sticky top-0 h-svh` keeps the nav at full viewport height as the page
  // scrolls. `overflow-hidden` clips the inner fixed-width content while the
  // outer `width` animates between 0 and `--spacing-sidebar-width`. `aria-hidden`
  // while closed prevents screen-reader and keyboard access to hidden links.
  return (
    <aside
      aria-label={t('admin.a11y.settings_navigation')}
      aria-hidden={!open}
      data-state={open ? 'open' : 'closed'}
      className={cn(
        'sticky top-0 z-30 hidden h-svh shrink-0 self-start overflow-hidden bg-sidebar text-sidebar-foreground transition-[width,border-color] duration-200 ease-out lg:block',
        open
          ? 'lg:w-(--spacing-sidebar-width) border-r border-border/50'
          : 'lg:w-0 border-r-0 border-transparent',
      )}
    >
      <div
        className={cn(
          'flex h-full w-(--spacing-sidebar-width) flex-col gap-2 overflow-y-auto py-2 transition-opacity duration-200',
          open ? 'opacity-100 delay-100' : 'pointer-events-none opacity-0',
        )}
      >
        {visible.groups.map(({ group, entries }) => (
          <SidebarGroup key={group.key}>
            <SidebarGroupLabel>
              {group.labelKey ? t(group.labelKey) : group.label}
            </SidebarGroupLabel>
            <SidebarMenu>
              {entries.map((entry) => (
                <SettingsItem
                  key={entry.key}
                  entry={entry}
                  storeId={id}
                  // While closed, keep the items out of the tab order — the
                  // `aria-hidden` above does not, by itself, prevent focus.
                  tabIndex={open ? 0 : -1}
                />
              ))}
            </SidebarMenu>
          </SidebarGroup>
        ))}
      </div>
    </aside>
  )
}

function SettingsItem({
  entry,
  storeId,
  tabIndex,
}: {
  entry: SettingsNavEntry
  storeId: string
  tabIndex: number
}) {
  const { t } = useTranslation()
  const routerState = useRouterState()
  const currentPath = routerState.location.pathname
  const url = `/${storeId}/settings${entry.path}`
  const isActive = currentPath === url || currentPath.startsWith(`${url}/`)
  const Icon = entry.icon ?? PackageIcon
  const label = entry.labelKey ? t(entry.labelKey) : entry.label

  return (
    <SidebarMenuItem>
      {/* No `tooltip` prop — it keys off the primary sidebar's collapsed state
          via `useSidebar()`, which would fire spuriously in this secondary nav. */}
      <SidebarMenuButton asChild isActive={isActive}>
        <Link to={url} tabIndex={tabIndex}>
          <NavIcon icon={Icon} isActive={isActive} />
          <span>{label}</span>
          {entry.comingSoon && (
            <Badge className="ml-auto h-5 bg-sidebar-accent px-1.5 py-0 text-[10px] font-normal text-sidebar-foreground/70">
              Soon
            </Badge>
          )}
        </Link>
      </SidebarMenuButton>
    </SidebarMenuItem>
  )
}

function filterByPermissions(
  snapshot: SettingsNavSnapshot,
  permissions: Permissions,
): SettingsNavSnapshot {
  const groups = snapshot.groups
    .map(({ group, entries }) => ({
      group,
      entries: entries.filter((e) => !e.subject || permissions.can('read', e.subject)),
    }))
    .filter((g) => g.entries.length > 0)
  return {
    groups,
    all: groups.flatMap((g) => g.entries),
  }
}
