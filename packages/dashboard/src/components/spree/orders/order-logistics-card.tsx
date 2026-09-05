import type { Order } from '@spree/admin-sdk'
import { Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/**
 * The rollup a forwarder quotes against, as it was when the order was placed.
 * Serialized as an opaque record, so narrow it here rather than trusting it.
 */
interface FreightSummary {
  total_units?: number
  total_cartons?: number
  total_pallets?: number
  total_volume?: string
  total_weight?: string
  complete?: boolean
}

interface PaymentSchedule {
  display_deposit_amount?: string | null
  deposit_paid?: boolean
  balance_due_label?: string | null
}

function asRecord<T>(value: unknown): T | null {
  return value && typeof value === 'object' ? (value as T) : null
}

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

  const freight = asRecord<FreightSummary>(order.freight_summary)
  const schedule = asRecord<PaymentSchedule>(order.payment_schedule)

  // Nothing measured and nothing deferred is an ordinary retail order, which
  // this card has nothing to say about.
  if (!freight && !schedule) return null

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

        {schedule && (
          <div className="mt-1 flex flex-col gap-2 border-t pt-3">
            {schedule.display_deposit_amount != null && (
              <Row
                label={t('admin.orders.detail.logistics.deposit')}
                value={schedule.display_deposit_amount}
              />
            )}
            <Row
              label={t('admin.orders.detail.logistics.paid')}
              value={order.display_payment_total}
            />
            {/* The merchant's own wording for when the rest falls due, when
                the terms carried one. */}
            <Row
              label={schedule.balance_due_label ?? t('admin.orders.detail.logistics.balance')}
              value={order.display_amount_due}
            />
          </div>
        )}
      </CardContent>
    </Card>
  )
}
