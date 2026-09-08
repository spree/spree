import type { StockMovement } from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Pagination,
  RelativeTime,
  StatusBadge,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * Why the on-hand number is what it is.
 *
 * Movement history is only ever read in the context of a variant or a
 * warehouse — "why is this SKU 47?" and "what changed in Brooklyn this week?"
 * are the questions merchants actually ask, and the legacy admin's
 * undifferentiated firehose answered neither
 * (docs/plans/6.0-inventory-operations.md). So this is a panel, never a page.
 */
export function StockHistoryCard({
  variantIds,
  stockLocationId,
  title,
}: {
  /** One SKU's history, or a product's across all of its variants. */
  variantIds?: string[]
  stockLocationId?: string | null
  title?: string
}) {
  const { t } = useTranslation()
  const [page, setPage] = useState(1)

  // Movements carry no variant or location of their own — they hang off a
  // stock level, which is the (variant, warehouse) pair — so both filters
  // reach through it.
  const filter = variantIds
    ? { stock_level_variant_id_in: variantIds }
    : { stock_level_stock_location_id_eq: stockLocationId }

  const scopeKey = variantIds ? variantIds.join(',') : (stockLocationId ?? '')

  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('stock-movements', `${scopeKey}-${page}`),
    queryFn: () => adminClient.stockMovements.list({ page, limit: 10, ...filter }),
    enabled: variantIds ? variantIds.length > 0 : !!stockLocationId,
  })

  const movements = data?.data ?? []
  const paginated = (data?.meta?.pages ?? 1) > 1

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title ?? t('admin.stock_history.title')}</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        {isLoading ? (
          <p className="p-3 text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        ) : movements.length === 0 ? (
          <p className="p-3 text-muted-foreground text-sm">{t('admin.stock_history.empty')}</p>
        ) : (
          <>
            {/* The pagination bar brings its own top rule and padding, so it
                takes the card's bottom curve when it is there — and the last
                row takes it when the history fits on one page. */}
            <Table roundedBottom={!paginated}>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.stock_history.columns.when')}</TableHead>
                  <TableHead>{t('admin.stock_history.columns.change')}</TableHead>
                  <TableHead>{t('admin.stock_history.columns.kind')}</TableHead>
                  <TableHead>{t('admin.stock_history.columns.cause')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {movements.map((movement) => (
                  <TableRow key={movement.id}>
                    <TableCell className="whitespace-nowrap text-muted-foreground text-sm">
                      <RelativeTime iso={movement.created_at} />
                    </TableCell>
                    <TableCell className="font-medium tabular-nums">
                      <QuantityChange movement={movement} />
                    </TableCell>
                    <TableCell>
                      {movement.kind ? (
                        <StatusBadge
                          status={movement.kind}
                          label={t(`admin.stock_history.kinds.${movement.kind}`)}
                        />
                      ) : (
                        '—'
                      )}
                    </TableCell>
                    <TableCell className="text-sm">
                      <MovementCause movement={movement} />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {paginated && data?.meta && <Pagination meta={data.meta} onPageChange={setPage} />}
          </>
        )}
      </CardContent>
    </Card>
  )
}

/**
 * The direction lives in the kind, not the sign: `shipped` rows are stored
 * positive and read as a departure, while `adjusted` keeps whatever sign the
 * merchant's correction had.
 */
function QuantityChange({ movement }: { movement: StockMovement }) {
  // Only `shipped` needs flipping: it is stored positive and means a
  // departure. `adjusted` already carries the sign the merchant entered, and
  // every other kind is an addition.
  const signed = movement.kind === 'shipped' ? -Math.abs(movement.quantity) : movement.quantity

  return (
    <span className={signed < 0 ? 'text-danger' : 'text-success'}>
      {signed > 0 ? `+${signed}` : signed}
    </span>
  )
}

/** What caused the change, in the merchant's own vocabulary. */
function MovementCause({ movement }: { movement: StockMovement }) {
  const { t } = useTranslation()

  if (movement.purchase_order_id) {
    return <span>{t('admin.stock_history.causes.purchase_order')}</span>
  }
  if (movement.stock_transfer_id) {
    return <span>{t('admin.stock_history.causes.stock_transfer')}</span>
  }
  if (movement.return_id) return <span>{t('admin.stock_history.causes.return')}</span>
  if (movement.exchange_id) return <span>{t('admin.stock_history.causes.exchange')}</span>
  if (movement.fulfillment_id) return <span>{t('admin.stock_history.causes.fulfillment')}</span>
  if (movement.order_id) return <span>{t('admin.stock_history.causes.order')}</span>

  return (
    <span className="text-muted-foreground">
      {movement.reason ?? t('admin.stock_history.causes.manual')}
    </span>
  )
}
