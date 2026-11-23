import {
  StockLocationsPage,
  stockLocationsSearchSchema,
  type TableView,
} from '@spree/dashboard-core'
import { createFileRoute } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import type { z } from 'zod/v4'
import { StockHistoryCard } from '../../../../components/spree/stock-history-card'
import { StockLevelsPanel } from '../../../../components/spree/stock-levels-panel'
import { useSellers } from '../../../../hooks/use-sellers'
// Adds the seller column to the shared table — operator-only, see the file.
import '../../../../tables/stock-locations'

export const Route = createFileRoute('/_authenticated/$storeId/settings/stock-locations')({
  validateSearch: stockLocationsSearchSchema,
  component: StockLocationsRoute,
})

/**
 * The page itself lives in `@spree/dashboard-core` so the marketplace seller
 * panel renders the same one. What stays here is the route (paths differ per
 * panel, and file routes are generated per app), the on-hand stock editor and
 * the movement history — both read the Admin API and link to the operator's
 * product pages.
 */
function StockLocationsRoute() {
  // Cast: the inferred search type unions with the parent layout's shape,
  // which does not know about our `edit`/`new` keys. The runtime schema is
  // still the source of truth — this gets past the parent-union narrowing.
  const search = Route.useSearch() as z.infer<typeof stockLocationsSearchSchema>
  const views = useOwnerViews()

  // Held back until it is known whether there are sellers, so the list does
  // not load every location and then narrow to the operator's own.
  if (views === undefined) return null

  return (
    <StockLocationsPage
      search={search}
      views={views ?? undefined}
      stockLevelsPanel={StockLevelsPanel}
      activityPanel={ActivityPanel}
    />
  )
}

/** What changed in this warehouse — the reconciliation view. */
function ActivityPanel({ stockLocationId }: { stockLocationId: string }) {
  return <StockHistoryCard stockLocationId={stockLocationId} />
}

/**
 * On a marketplace, the operator's own locations and their sellers' as two
 * tabs. Every seller has a default location of their own, so in one list the
 * operator could not tell which Default was theirs. A store without sellers
 * gets no tabs. `undefined` while that is still being found out.
 */
function useOwnerViews(): TableView[] | null | undefined {
  const { t } = useTranslation()
  // A role that cannot read sellers gets an error here, and no tabs.
  const { data: sellers, isPending } = useSellers({ limit: 1 })

  if (isPending) return undefined
  if ((sellers?.meta?.count ?? 0) === 0) return null

  return [
    {
      key: 'own',
      label: t('admin.stock_locations.views.own'),
      params: { seller_id_null: true },
      hiddenColumns: ['seller_id'],
    },
    {
      key: 'sellers',
      label: t('admin.stock_locations.views.sellers'),
      params: { seller_id_not_null: true },
    },
  ]
}
