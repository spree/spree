import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbPage,
  BreadcrumbSeparator,
} from '@spree/dashboard-ui'
import { MenuIcon } from '@spree/dashboard-ui/icons'
import { Link, useParams, useRouterState } from '@tanstack/react-router'
import { Fragment, type ReactNode, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { isPathWithin, type NavEntry, resolveNavLabel, useNavEntries } from '../lib/nav-registry'
import { type SettingsNavEntry, useSettingsNav } from '../lib/settings-nav-registry'

interface Crumb {
  label: string
  /** Omitted on the final crumb, which renders as plain text. */
  to?: string
}

/**
 * Location trail for the TopBar, derived from the current path by matching it
 * against the nav registries. Fills the empty space beside the search box and
 * gives deep pages the orientation the collapsed sidebars stop providing.
 *
 * Only segments the registries know are named. A record-detail path
 * (`/settings/delivery-profiles/dp_123`) resolves as far as its section and
 * stops there — inventing a crumb for an id the shell can't name would be
 * worse than a shorter trail, and the page's own `PageHeader` carries the
 * record's title anyway.
 */
export function TopBarBreadcrumbs({ tenantId }: { tenantId?: string } = {}) {
  const trail = useCrumbs(tenantId)
  if (!trail) return null

  return <CrumbTrail crumbs={trail.crumbs} pathname={trail.pathname} className="min-w-0" />
}

/**
 * Breadcrumbs for a narrow screen, as a row beneath the TopBar rather than
 * inside it — the bar has no width to spare on a phone, so the trail lives on
 * its own line and scrolls sideways instead of wrapping.
 *
 * Only rendered where it earns the vertical space: inside settings, and on
 * record pages. A top-level list page would only repeat its own heading.
 *
 * Inside settings the leading crumb is a button rather than a link — it opens
 * the settings nav sheet, which is the fastest way between two settings pages
 * on a screen with no settings sidebar.
 */
export function MobileBreadcrumbBar({
  onOpenSettingsNav,
  tenantId,
}: {
  onOpenSettingsNav?: () => void
  /** See `SettingsSidebar` — a seller id on the marketplace panel. */
  tenantId?: string
}) {
  const trail = useCrumbs(tenantId)
  if (!trail) return null

  const { crumbs, pathname, inSettings } = trail

  return (
    <div className="flex h-11 shrink-0 items-center border-b border-border/75 bg-background px-4 md:hidden">
      <CrumbTrail
        crumbs={crumbs}
        pathname={pathname}
        className="min-w-0 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        // In settings the leading crumb opens the nav sheet instead of
        // navigating — it is the only way between settings pages on a phone.
        renderFirst={
          inSettings && onOpenSettingsNav
            ? (crumb) => (
                <button
                  type="button"
                  onClick={onOpenSettingsNav}
                  // 44px tall via the row; the negative inline margin keeps the
                  // text on the page gutter while the tap area overhangs it.
                  className="-ms-2 inline-flex h-11 items-center gap-1 rounded-lg px-2 text-sm text-muted-foreground transition-colors hover:text-foreground"
                >
                  <MenuIcon className="size-4" />
                  {crumb.label}
                </button>
              )
            : undefined
        }
      />
    </div>
  )
}

function CrumbTrail({
  crumbs,
  pathname,
  className,
  renderFirst,
}: {
  crumbs: Crumb[]
  pathname: string
  className?: string
  /** Replaces the leading crumb's content — used for the settings nav trigger. */
  renderFirst?: (crumb: Crumb) => ReactNode
}) {
  return (
    <Breadcrumb className={className}>
      <BreadcrumbList className="flex-nowrap">
        {crumbs.map((crumb, index) => {
          // The trail ends in a link, not plain text, when the last crumb names
          // a section the current page sits *inside* (a record page, whose own
          // name the registries can't supply) — there it is the way back up.
          const isCurrentPage = crumb.to === pathname
          const custom = index === 0 ? renderFirst?.(crumb) : undefined
          return (
            // Crumbs are a fixed trail for one path — no stable id beyond
            // position. The separator is a sibling `<li>`, never a child of
            // BreadcrumbItem — nesting one list item inside another is invalid.
            // biome-ignore lint/suspicious/noArrayIndexKey: positional by nature
            <Fragment key={index}>
              <BreadcrumbItem className="min-w-0">
                {custom ??
                  (isCurrentPage || !crumb.to ? (
                    <BreadcrumbPage className="truncate">{crumb.label}</BreadcrumbPage>
                  ) : (
                    <BreadcrumbLink asChild>
                      <Link to={crumb.to} className="truncate">
                        {crumb.label}
                      </Link>
                    </BreadcrumbLink>
                  ))}
              </BreadcrumbItem>
              {index < crumbs.length - 1 && <BreadcrumbSeparator />}
            </Fragment>
          )
        })}
      </BreadcrumbList>
    </Breadcrumb>
  )
}

/** Resolves the trail for the current path, or null when there is nothing worth showing. */
function useCrumbs(tenantId?: string): {
  crumbs: Crumb[]
  pathname: string
  inSettings: boolean
} | null {
  const { t } = useTranslation()
  const { storeId: routeStoreId } = useParams({ strict: false }) as { storeId?: string }
  const storeId = tenantId ?? routeStoreId
  const pathname = useRouterState({ select: (s) => s.location.pathname })
  const { main, bottom } = useNavEntries()
  const settings = useSettingsNav()

  // Memoized because both breadcrumb surfaces are mounted at once (the
  // responsive split is CSS, not conditional mounting), so an unmemoized pass
  // would run twice on every render of the app-wide TopBar.
  return useMemo(() => {
    if (!storeId) return null

    const crumbs = buildCrumbs({ pathname, storeId, main, bottom, settings: settings.all, t })
    // A lone crumb naming the page you are already on says nothing the
    // PageHeader doesn't. A lone crumb naming the *section* of a record page
    // does — it is the way back up — so that one stays.
    if (crumbs.length === 0) return null
    if (crumbs.length === 1 && crumbs[0].to === pathname) return null

    return { crumbs, pathname, inSettings: isPathWithin(pathname, `/${storeId}/settings`) }
  }, [pathname, storeId, main, bottom, settings.all, t])
}

function buildCrumbs({
  pathname,
  storeId,
  main,
  bottom,
  settings,
  t,
}: {
  pathname: string
  storeId: string
  main: NavEntry[]
  bottom: NavEntry[]
  settings: SettingsNavEntry[]
  t: (key: string) => string
}): Crumb[] {
  const settingsRoot = `/${storeId}/settings`

  if (isPathWithin(pathname, settingsRoot)) {
    const crumbs: Crumb[] = [{ label: t('admin.settings_page.title'), to: settingsRoot }]
    const entry = bestMatch(settings, (e) => `${settingsRoot}${e.path}`, pathname)
    if (entry) {
      crumbs.push({ label: resolveNavLabel(entry, t), to: `${settingsRoot}${entry.path}` })
    }
    return crumbs
  }

  // One pass handles both a page under its parent's path and a child that sits
  // outside it (Returns lives at `/returns` but nests under Orders), so a
  // matching child alone is enough to claim the trail.
  for (const parent of [...main, ...bottom]) {
    const parentUrl = `/${storeId}${parent.path}`
    const child = bestMatch(parent.children ?? [], (c) => `/${storeId}${c.path}`, pathname)
    const parentMatches = parent.path !== '/' && isPathWithin(pathname, parentUrl)
    if (!child && !parentMatches) continue

    const crumbs: Crumb[] = [{ label: resolveNavLabel(parent, t), to: parentUrl }]
    if (child) crumbs.push({ label: resolveNavLabel(child, t), to: `/${storeId}${child.path}` })
    return crumbs
  }

  return []
}

/**
 * The matching entry whose URL is longest, so `/webhooks/wh_1` prefers
 * `/webhooks` over a shorter entry that also prefixes it. Written as a scan
 * rather than sort-then-find: this runs for every entry on every navigation,
 * and the ordering is needed only to break ties.
 */
function bestMatch<T>(
  entries: readonly T[],
  urlOf: (entry: T) => string,
  pathname: string,
): T | undefined {
  let best: T | undefined
  let bestLength = -1
  for (const entry of entries) {
    const url = urlOf(entry)
    if (!isPathWithin(pathname, url) || url.length <= bestLength) continue
    best = entry
    bestLength = url.length
  }
  return best
}
