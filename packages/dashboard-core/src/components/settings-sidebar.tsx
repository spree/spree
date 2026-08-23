import {
  Badge,
  cn,
  mobileDrawerClassName,
  SearchInput,
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SIDEBAR_WIDTH_MOBILE,
  SidebarGroup,
  SidebarGroupLabel,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from '@spree/dashboard-ui'
import { Link, useParams, useRouterState } from '@tanstack/react-router'
import { ArrowLeftIcon, PackageIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { isPathWithin, resolveNavLabel } from '../lib/nav-registry'
import {
  filterSettingsByPermissions,
  filterSettingsByQuery,
  type SettingsNavEntry,
  useSettingsNav,
} from '../lib/settings-nav-registry'
import { usePermissions } from '../providers/permission-provider'
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
        open ? 'lg:w-(--spacing-sidebar-width) border-e' : 'lg:w-0 border-e-0 border-transparent',
      )}
    >
      {/* `quiet-scrollbar` rather than the browser default: this nav is an
          inset panel beside the primary sidebar, and a full-width native
          scrollbar cuts a heavy grey stripe down the middle of the chrome. */}
      <div
        className={cn(
          'quiet-scrollbar h-full w-(--spacing-sidebar-width) overflow-y-auto transition-opacity duration-200',
          open ? 'opacity-100 delay-100' : 'pointer-events-none opacity-0',
        )}
      >
        {/* Names the area and offers the way out. Without it this panel is
            visually identical to the primary sidebar, so nothing says the
            merchant has entered a different part of the app — and the only
            exit is the icon rail beside it. `h-header-height` matches the
            store switcher opposite, so the two line up. */}
        <div className="flex h-header-height items-center gap-1 px-2">
          <Link
            to={`/${storeId}` as never}
            tabIndex={open ? 0 : -1}
            aria-label={t('admin.settings_page.back_to_dashboard')}
            className="inline-flex size-8 shrink-0 items-center justify-center rounded-lg text-sidebar-foreground/70 transition-colors hover:bg-sidebar-accent hover:text-sidebar-foreground"
          >
            <ArrowLeftIcon className="size-4" />
          </Link>
          <span className="truncate font-medium text-sm">{t('admin.settings_page.title')}</span>
        </div>

        <SettingsNavBody tabIndex={open ? 0 : -1} />
      </div>
    </aside>
  )
}

/**
 * The settings nav on a narrow screen, where `SettingsSidebar` is hidden.
 * Without it the only way between two settings pages is a round trip through
 * the landing page.
 *
 * Rendered as a sheet rather than an inline panel because the settings content
 * needs the full width on a phone; `data-mobile` opts its rows into the same
 * touch sizing the primary drawer uses.
 */
export function SettingsNavSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="left"
        data-mobile="true"
        className={cn(mobileDrawerClassName, 'gap-0 lg:hidden')}
        style={{ width: SIDEBAR_WIDTH_MOBILE }}
      >
        {/* `h-header-height` matches the store header in the primary drawer, so
            the two nav sheets open to the same silhouette — and it gives the
            close button a full-height touch target rather than a 42px band. */}
        <SheetHeader className="h-header-height justify-center border-b border-sidebar-border px-4 py-0">
          <SheetTitle className="text-base">{t('admin.settings_page.title')}</SheetTitle>
        </SheetHeader>
        <div className="quiet-scrollbar flex-1 overflow-y-auto">
          {/* Close as the link is tapped rather than from an effect watching the
              path: this body renders inside the Sheet, so it remounts on every
              open and an effect could not tell "just opened" from "navigated". */}
          <SettingsNavBody tabIndex={0} onNavigate={() => onOpenChange(false)} />
        </div>
      </SheetContent>
    </Sheet>
  )
}

/** Search box plus grouped entries — shared by the desktop aside and the sheet. */
function SettingsNavBody({
  tabIndex,
  onNavigate,
}: {
  tabIndex: number
  /** Called when an entry is tapped — closes the mobile sheet. */
  onNavigate?: () => void
}) {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const id = storeId ?? 'default'
  const snapshot = useSettingsNav()
  const { permissions } = usePermissions()
  const [query, setQuery] = useState('')
  // Permission filtering depends only on the snapshot, so it survives typing.
  const allowed = useMemo(
    () => filterSettingsByPermissions(snapshot, permissions),
    [snapshot, permissions],
  )
  const visible = useMemo(() => filterSettingsByQuery(allowed, query, t), [allowed, query, t])

  return (
    // Delegated rather than per-link: entries render through `asChild` Slots
    // that clone their own `onClick` over the child's.
    // biome-ignore lint/a11y/noStaticElementInteractions: delegated link taps only
    // biome-ignore lint/a11y/useKeyWithClickEvents: links keep their own keyboard behaviour
    <div
      className="flex flex-col gap-2 py-2"
      onClick={(event) => {
        if ((event.target as HTMLElement).closest('a')) onNavigate?.()
      }}
    >
      <div className="px-2">
        <SearchInput
          value={query}
          onValueChange={setQuery}
          placeholder={t('admin.settings_page.search_placeholder')}
          aria-label={t('admin.settings_page.search_placeholder')}
          clearLabel={t('admin.common.clear')}
          tabIndex={tabIndex}
          className="h-8 bg-sidebar text-sm in-data-[mobile=true]:h-11 in-data-[mobile=true]:text-base"
        />
      </div>

      {visible.groups.length === 0 && (
        <p className="px-4 py-2 text-sm text-sidebar-foreground/70">
          {t('admin.settings_page.no_results', { query: query.trim() })}
        </p>
      )}

      {visible.groups.map(({ group, entries }) => (
        <SidebarGroup key={group.key}>
          <SidebarGroupLabel>{resolveNavLabel(group, t)}</SidebarGroupLabel>
          <SidebarMenu>
            {entries.map((entry) => (
              <SettingsItem
                key={entry.key}
                entry={entry}
                storeId={id}
                // While the desktop panel is closed, keep items out of the tab
                // order — `aria-hidden` does not, by itself, prevent focus.
                tabIndex={tabIndex}
              />
            ))}
          </SidebarMenu>
        </SidebarGroup>
      ))}
    </div>
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
  const isActive = isPathWithin(currentPath, url)
  const Icon = entry.icon ?? PackageIcon
  const label = resolveNavLabel(entry, t)

  return (
    <SidebarMenuItem>
      {/* No `tooltip` prop — it keys off the primary sidebar's collapsed state
          via `useSidebar()`, which would fire spuriously in this secondary nav. */}
      <SidebarMenuButton asChild isActive={isActive}>
        <Link to={url} tabIndex={tabIndex}>
          <NavIcon icon={Icon} isActive={isActive} />
          <span>{label}</span>
          {entry.comingSoon && (
            <Badge className="ms-auto h-5 bg-sidebar-accent px-1.5 py-0 text-[10px] font-normal text-sidebar-foreground/70">
              Soon
            </Badge>
          )}
        </Link>
      </SidebarMenuButton>
    </SidebarMenuItem>
  )
}
