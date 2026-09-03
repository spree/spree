import {
  filterSettingsByPermissions,
  filterSettingsByQuery,
  PageHeader,
  resolveNavDescription,
  resolveNavLabel,
  type SettingsNavEntry,
  usePermissions,
  useSettingsNav,
} from '@spree/dashboard-core'
import { Card, SearchInput } from '@spree/dashboard-ui'
import { PackageIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

export const Route = createFileRoute('/_authenticated/$storeId/settings/')({
  component: SettingsIndexPage,
})

/**
 * Settings landing page — a card grid of every settings area the current staff
 * member can reach, grouped the same way the sidebar groups them.
 *
 * It doubles as the settings navigation below `lg`, where `SettingsSidebar` is
 * hidden: on a narrow viewport this grid is the only way into the area, so it
 * must never be replaced by a redirect to a specific page.
 */
function SettingsIndexPage() {
  const { t } = useTranslation()
  const snapshot = useSettingsNav()
  const { permissions } = usePermissions()
  const [query, setQuery] = useState('')

  // Permission filtering depends only on the snapshot, so it survives typing.
  const allowed = useMemo(
    () => filterSettingsByPermissions(snapshot, permissions),
    [snapshot, permissions],
  )
  const groups = useMemo(() => filterSettingsByQuery(allowed, query, t).groups, [allowed, query, t])

  return (
    <div className="flex flex-col gap-6">
      <PageHeader
        title={t('admin.settings_page.title')}
        subtitle={t('admin.settings_page.description')}
      />

      {/* Hidden from `lg`, where the settings sidebar is on screen listing the
          same entries and carrying the same search. Below that the sidebar is
          gone, so this is the only way to filter — and the only navigation. */}
      <div className="lg:hidden">
        <SearchInput
          value={query}
          onValueChange={setQuery}
          placeholder={t('admin.settings_page.search_placeholder')}
          aria-label={t('admin.settings_page.search_placeholder')}
          clearLabel={t('admin.common.clear')}
          className="h-11 max-w-md"
        />
      </div>

      {groups.length === 0 ? (
        <p className="text-sm text-muted-foreground">
          {t('admin.settings_page.no_results', { query: query.trim() })}
        </p>
      ) : (
        groups.map(({ group, entries }) => (
          <section key={group.key} className="flex flex-col gap-3">
            <h2 className="text-sm font-medium text-muted-foreground">
              {resolveNavLabel(group, t)}
            </h2>
            <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {entries.map((entry) => (
                <SettingsCard key={entry.key} entry={entry} />
              ))}
            </div>
          </section>
        ))
      )}
    </div>
  )
}

function SettingsCard({ entry }: { entry: SettingsNavEntry }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const Icon = entry.icon ?? PackageIcon
  const label = resolveNavLabel(entry, t)
  const description = resolveNavDescription(entry, t)

  return (
    <Card className="p-0 transition-colors hover:bg-accent/80 hover:border-neutral-200 dark:hover:border-neutral-800">
      {/* The whole card is the target — a small title-only link would fail the
          44px minimum on touch and leaves most of the card dead to a click. */}
      {/* Paths come from a runtime registry plugins extend, so they can't be
          checked against the generated route tree. */}
      <Link
        to={`/${storeId}/settings${entry.path}` as never}
        // The whole card is the target, so without a replacement for the
        // suppressed outline a keyboard user tabbing the grid cannot tell which
        // card they are on. A solid ring rather than the border pair buttons
        // use: this link draws no border of its own to recolour.
        className="flex h-full items-start gap-3 rounded-xl p-4 outline-none focus-visible:shadow-[0_0_0_2px_var(--ring)]"
      >
        <Icon className="mt-0.5 size-6 shrink-0 text-muted-foreground opacity-80 hover:opacity-100" />
        <span className="flex min-w-0 flex-col gap-1">
          <span className="text-sm font-medium leading-none">{label}</span>
          {description && <span className="text-sm text-muted-foreground">{description}</span>}
        </span>
      </Link>
    </Card>
  )
}
