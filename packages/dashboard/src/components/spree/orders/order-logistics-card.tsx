import type { Order } from '@spree/admin-sdk'
import { Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-baseline justify-between gap-4 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-medium tabular-nums">{value}</span>
    </div>
  )
}

/**
 * What is being shipped, and what is still owed for it.
 *
 * Both halves are read from what the order froze at placement rather than
 * re-derived from the catalog: a carton resized months later must not silently
 * restate the volume a forwarder already quoted against.
 */
export function OrderLogisticsCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  const freight = order.freight_summary

  // Nothing measured is an ordinary retail order, which this card has
  // nothing to say about.
  if (!freight) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.logistics.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        {freight && (
          <>
            {freight.total_units != null && (
              <Row
                label={t('admin.orders.detail.logistics.units')}
                value={String(freight.total_units)}
              />
            )}
            {freight.total_cartons != null && (
              <Row
                label={t('admin.orders.detail.logistics.cartons')}
                value={String(freight.total_cartons)}
              />
            )}
            {freight.total_pallets != null && (
              <Row
                label={t('admin.orders.detail.logistics.pallets')}
                value={String(freight.total_pallets)}
              />
            )}
            {freight.total_volume != null && (
              <Row
                label={t('admin.orders.detail.logistics.volume')}
                value={t('admin.orders.detail.logistics.cbm', { value: freight.total_volume })}
              />
            )}
            {freight.total_weight != null && (
              <Row
                label={t('admin.orders.detail.logistics.weight')}
                value={t('admin.orders.detail.logistics.kg', { value: freight.total_weight })}
              />
            )}
            {/* Said plainly rather than left to be inferred from the figures:
                an incomplete rollup understates every one of them. */}
            {freight.complete === false && (
              <p className="text-sm text-muted-foreground">
                {t('admin.orders.detail.logistics.incomplete')}
              </p>
            )}
          </>
        )}
      </CardContent>
    </Card>
  )
}
