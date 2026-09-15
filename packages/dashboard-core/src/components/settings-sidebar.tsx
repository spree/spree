import {
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
  SidebarHeader,
  SidebarMenu,
  SidebarMenuBadge,
  SidebarMenuButton,
  SidebarMenuItem,
} from '@spree/dashboard-ui'
import { ArrowLeftIcon, PackageIcon } from '@spree/dashboard-ui/icons'
import { Link, useParams, useRouterState } from '@tanstack/react-router'
import { useEffect, useMemo, useState, useSyncExternalStore } from 'react'
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
 * sidebar so it can extend the full height of the content sheet. Width
 * animates between `0` and
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
export function SettingsSidebar({
  open,
  tenantId,
}: {
  open: boolean
  /**
   * The id the settings links are built under — a store for the operator's
   * dashboard, a seller for the marketplace panel. Falls back to reading
   * `storeId` from the route so the operator's dashboard needs no change;
   * a panel routed on anything else passes its own, exactly as `useNavItems`
   * takes one.
   */
  tenantId?: string
}) {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  // Held here rather than in the body: the search box lives in the header,
  // and the list it filters scrolls below it.
  const [query, setQuery] = useState('')

  // `h-full` fills the content sheet, which is itself exactly viewport-height
  // and scrolls internally — so the nav stays put as the page scrolls without
  // needing to be sticky. `overflow-hidden` clips the inner fixed-width content
  // while the outer `width` animates between 0 and `--spacing-sidebar-width`.
  // `aria-hidden` while closed prevents screen-reader and keyboard access to
  // hidden links.
  return (
    <aside
      aria-label={t('admin.a11y.settings_navigation')}
      aria-hidden={!open}
      data-state={open ? 'open' : 'closed'}
      className={cn(
        // `bg-card`, the content sheet's own colour: this rail is a column OF
        // the sheet rather than an extension of the nav rail beside it, so it
        // reads as part of the page it is navigating rather than as a second
        // band of chrome.
        'z-30 hidden h-full shrink-0 overflow-hidden bg-muted text-sidebar-foreground transition-[width,border-color] duration-200 ease-out lg:block',
        open
          ? 'lg:w-(--spacing-sidebar-width) border-e border-border-subtle'
          : 'lg:w-0 border-e-0 border-transparent',
      )}
    >
      <div
        className={cn(
          'flex h-full w-(--spacing-sidebar-width) flex-col transition-opacity duration-200',
          open ? 'opacity-100 delay-100' : 'pointer-events-none opacity-0',
        )}
      >
        {/* Names the area, offers the way out, and carries the search box —
            the same pairing the primary sidebar's `SidebarHeader` holds, so
            the two rails open to the same silhouette.

            A sibling of the scroll area rather than a sticky child of it: the
            fade below is a `mask-image` on the scrolling element, and a mask
            applies to sticky descendants too — a header inside it would
            dissolve along with the rows it is meant to stay above. */}
        <SidebarHeader className="shrink-0 gap-2 pb-2">
          {/* `h-rail-header-height` matches the store switcher opposite, so the
              two line up. */}
          <div className="flex h-rail-header-height items-center gap-1">
            <Link
              to={`/${tenantId ?? storeId}` as never}
              tabIndex={open ? 0 : -1}
              aria-label={t('admin.settings_page.back_to_dashboard')}
              className="inline-flex size-8 shrink-0 items-center justify-center rounded-lg text-sidebar-foreground/70 transition-colors hover:bg-sidebar-accent hover:text-sidebar-foreground"
            >
              <ArrowLeftIcon className="size-4" />
            </Link>
            <span className="truncate font-medium text-sm">{t('admin.settings_page.title')}</span>
          </div>

          <SettingsNavSearch value={query} onValueChange={setQuery} tabIndex={open ? 0 : -1} />
        </SidebarHeader>

        {/* `quiet-scrollbar` rather than the browser default: this nav is an
            inset panel beside the primary sidebar, and a full-width native
            scrollbar cuts a heavy grey stripe down the middle of the chrome.

            `scroll-fade` dissolves the rows into the header above and the
            panel's foot below, and tracks the scroll position — crisp at the
            top until there is something scrolled past, clear again at the
            bottom once the end is reached. Falls back to a static fade on both
            edges where scroll-driven animations are unsupported. */}
        <div className="quiet-scrollbar scroll-fade min-h-0 flex-1 overflow-y-auto">
          <SettingsNavBody
            tabIndex={open ? 0 : -1}
            tenantId={tenantId}
            query={query}
            onQueryChange={setQuery}
            renderSearch={false}
          />
        </div>
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
/**
 * Tracks the `lg` breakpoint the settings sheet is bounded by. `useIsMobile`
 * cannot stand in: it is fixed at 768px, and closing the sheet there would
 * strand it open across the 768-1024px band where it is still the only way to
 * navigate settings.
 */
const SETTINGS_SHEET_BREAKPOINT = 1024

function useIsSettingsSheetHidden() {
  return useSyncExternalStore(
    (onChange) => {
      const query = window.matchMedia(`(min-width: ${SETTINGS_SHEET_BREAKPOINT}px)`)
      query.addEventListener('change', onChange)
      return () => query.removeEventListener('change', onChange)
    },
    () => window.matchMedia(`(min-width: ${SETTINGS_SHEET_BREAKPOINT}px)`).matches,
    // Server render: assume the narrow layout so the sheet stays mountable.
    () => false,
  )
}

export function SettingsNavSheet({
  open,
  onOpenChange,
  tenantId,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** See `SettingsSidebar` — a seller id on the marketplace panel. */
  tenantId?: string
}) {
  const { t } = useTranslation()
  // Unmounted above `lg` rather than hidden with a utility class: `lg:hidden`
  // would hide the panel but leave the portal's overlay painted and the modal
  // focus trap armed, with nothing on screen to close it. Widening past the
  // breakpoint while the sheet is open also reports the close, so the caller's
  // state does not stay stuck open behind a desktop layout.
  const isDesktop = useIsSettingsSheetHidden()

  useEffect(() => {
    if (isDesktop && open) onOpenChange(false)
  }, [isDesktop, open, onOpenChange])

  if (isDesktop) return null

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent
        side="left"
        data-mobile="true"
        className={cn(mobileDrawerClassName, 'gap-0')}
        style={{ width: SIDEBAR_WIDTH_MOBILE }}
      >
        {/* `h-rail-header-height` matches the store header in the primary drawer, so
            the two nav sheets open to the same silhouette — and it gives the
            close button a full-height touch target rather than a 42px band. */}
        <SheetHeader className="h-rail-header-height justify-center border-b border-sidebar-border px-4 py-0">
          {/* Held at the default body size rather than the larger sheet
              title: this is a nav band matched to the store header, not a
              dialog heading. */}
          <SheetTitle className="text-base">{t('admin.settings_page.title')}</SheetTitle>
        </SheetHeader>
        <div className="quiet-scrollbar flex-1 overflow-y-auto">
          {/* Close as the link is tapped rather than from an effect watching the
              path: this body renders inside the Sheet, so it remounts on every
              open and an effect could not tell "just opened" from "navigated". */}
          <SettingsNavBody
            tabIndex={0}
            onNavigate={() => onOpenChange(false)}
            tenantId={tenantId}
          />
        </div>
      </SheetContent>
    </Sheet>
  )
}

/**
 * The settings search box. Extracted so the desktop rail can render it in its
 * fixed header while the sheet keeps it at the top of its scroll body.
 */
function SettingsNavSearch({
  value,
  onValueChange,
  tabIndex,
}: {
  value: string
  onValueChange: (next: string) => void
  tabIndex: number
}) {
  const { t } = useTranslation()
  return (
    <SearchInput
      value={value}
      onValueChange={onValueChange}
      placeholder={t('admin.settings_page.search_placeholder')}
      aria-label={t('admin.settings_page.search_placeholder')}
      clearLabel={t('admin.common.clear')}
      tabIndex={tabIndex}
      className="h-8 text-sm in-data-[mobile=true]:h-11 in-data-[mobile=true]:text-base"
    />
  )
}

/** Search box plus grouped entries — shared by the desktop aside and the sheet. */
function SettingsNavBody({
  tabIndex,
  onNavigate,
  tenantId,
  query: controlledQuery,
  onQueryChange,
  renderSearch = true,
}: {
  tabIndex: number
  /** Called when an entry is tapped — closes the mobile sheet. */
  onNavigate?: () => void
  /** See `SettingsSidebar` — a seller id on the marketplace panel. */
  tenantId?: string
  /**
   * Controlled query, passed by the desktop rail whose search box sits in the
   * header above this body. The sheet leaves both unset and keeps its own
   * state, since its search scrolls with the list.
   */
  query?: string
  onQueryChange?: (next: string) => void
  /** False when the caller renders the search box itself (the desktop rail). */
  renderSearch?: boolean
}) {
  const { t } = useTranslation()
  const { storeId } = useParams({ strict: false }) as { storeId?: string }
  const id = tenantId ?? storeId ?? 'default'
  const snapshot = useSettingsNav()
  const { permissions } = usePermissions()
  const [uncontrolledQuery, setUncontrolledQuery] = useState('')
  const query = controlledQuery ?? uncontrolledQuery
  const setQuery = onQueryChange ?? setUncontrolledQuery
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
      className={cn('flex flex-col gap-2 pb-2', renderSearch && 'pt-2')}
      onClick={(event) => {
        if ((event.target as HTMLElement).closest('a')) onNavigate?.()
      }}
    >
      {renderSearch && (
        <div className="px-2">
          <SettingsNavSearch value={query} onValueChange={setQuery} tabIndex={tabIndex} />
        </div>
      )}

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
          {entry.comingSoon && <SidebarMenuBadge className="ms-auto">Soon</SidebarMenuBadge>}
        </Link>
      </SidebarMenuButton>
    </SidebarMenuItem>
  )
}
