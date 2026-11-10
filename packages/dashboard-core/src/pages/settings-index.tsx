import { Card, cn, SearchInput } from '@spree/dashboard-ui'
import { ChevronRightIcon, PackageIcon } from '@spree/dashboard-ui/icons'
import { Link, Navigate } from '@tanstack/react-router'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { PageHeader } from '../components/page-header'
import { useSettingsRailShown } from '../components/settings-sidebar'
import { resolveNavDescription, resolveNavLabel } from '../lib/nav-registry'
import {
  filterSettingsByPermissions,
  filterSettingsByQuery,
  type SettingsNavEntry,
  useSettingsNav,
} from '../lib/settings-nav-registry'
import { usePermissions } from '../providers/permission-provider'

/**
 * Settings landing page — every settings area the current member can reach,
 * one card of rows per group, grouped the same way the sidebar groups them.
 *
 * Phones and tablets only. From `lg` the settings rail lists the same entries
 * beside the page, so this page would only repeat it; there it hands over to
 * the first section the member can open instead.
 *
 * Shared by the operator dashboard and the marketplace seller panel. Each
 * host passes its tenant id so the cards link under that panel's prefix
 * (`/$storeId/settings/…` or `/$sellerId/settings/…`).
 *
 * It doubles as the settings navigation below `lg`, where `SettingsSidebar` is
 * hidden: on a narrow viewport this list is the only way into the area, so the
 * redirect must stay bound to the rail being on screen.
 */
export function SettingsIndexPage({ tenantId }: { tenantId: string }) {
  const { t } = useTranslation()
  const snapshot = useSettingsNav()
  const { permissions, isLoading: permissionsLoading } = usePermissions()
  const [query, setQuery] = useState('')

  // Permission filtering depends only on the snapshot, so it survives typing.
  const allowed = useMemo(
    () => filterSettingsByPermissions(snapshot, permissions),
    [snapshot, permissions],
  )
  const groups = useMemo(() => filterSettingsByQuery(allowed, query, t).groups, [allowed, query, t])

  const railShown = useSettingsRailShown()
  const first = railShown
    ? allowed.groups.flatMap((g) => g.entries).find((entry) => !entry.comingSoon)
    : undefined
  if (first) return <Navigate to={`/${tenantId}/settings${first.path}` as never} replace />
  // Nothing to open yet while permissions load; render nothing rather than
  // flash the list the rail already shows. Loaded with nothing to open, the
  // list below says so rather than leaving the page blank.
  if (railShown && permissionsLoading) return null

  return (
    <div className="flex flex-col gap-8">
      <PageHeader
        title={t('admin.settings_page.title')}
        subtitle={t('admin.settings_page.description')}
      />

      <SearchInput
        value={query}
        onValueChange={setQuery}
        placeholder={t('admin.settings_page.search_placeholder')}
        aria-label={t('admin.settings_page.search_placeholder')}
        clearLabel={t('admin.common.clear')}
        className="h-11 max-w-md"
      />

      {groups.length === 0 ? (
        <p className="text-base text-muted-foreground">
          {t('admin.settings_page.no_results', { query: query.trim() })}
        </p>
      ) : (
        groups.map(({ group, entries }) => (
          <section key={group.key} className="flex flex-col gap-3">
            <h2 className="font-semibold text-base">{resolveNavLabel(group, t)}</h2>
            <Card className="gap-0 overflow-hidden">
              <ul>
                {entries.map((entry, index) => (
                  <SettingsIndexRow
                    key={entry.key}
                    entry={entry}
                    tenantId={tenantId}
                    divided={index > 0}
                  />
                ))}
              </ul>
            </Card>
          </section>
        ))
      )}
    </div>
  )
}

function SettingsIndexRow({
  entry,
  tenantId,
  divided,
}: {
  entry: SettingsNavEntry
  tenantId: string
  /** Draws the rule above the row's text, which starts past the icon. */
  divided: boolean
}) {
  const { t } = useTranslation()
  const Icon = entry.icon ?? PackageIcon
  const label = resolveNavLabel(entry, t)
  const description = resolveNavDescription(entry, t)

  return (
    <li>
      {/* The whole row is the target, so it clears the 44px touch minimum.
          Paths come from a runtime registry plugins extend, so they can't be
          checked against the generated route tree. */}
      <Link
        to={`/${tenantId}/settings${entry.path}` as never}
        // The row draws no border of its own, so focus gets an inset ring in
        // place of the suppressed outline.
        className="group flex items-center gap-3.5 ps-4 outline-none transition-colors hover:bg-accent focus-visible:shadow-[inset_0_0_0_2px_var(--ring)]"
      >
        <Icon className="size-5 shrink-0 text-muted-foreground transition-colors group-hover:text-foreground" />
        <span
          className={cn(
            'flex min-w-0 flex-1 items-center gap-3 py-3.5 pe-4',
            divided && 'border-border-subtle border-t',
          )}
        >
          <span className="flex min-w-0 flex-1 flex-col gap-0.5">
            <span className="flex items-center gap-1.5 text-base font-medium">
              {label}
              {entry.badge && <entry.badge />}
            </span>
            {description && (
              <span className="text-base text-muted-foreground md:truncate">{description}</span>
            )}
          </span>
          <ChevronRightIcon className="size-4 shrink-0 text-muted-foreground rtl:rotate-180" />
        </span>
      </Link>
    </li>
  )
}
