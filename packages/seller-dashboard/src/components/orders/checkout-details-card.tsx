import { formatCustomFieldValue } from '@spree/dashboard-core'
import { Card, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import type { Order } from '@spree/seller-sdk'
import { useTranslation } from 'react-i18next'
import { useStoreTimezone } from '../../hooks/use-store-timezone'

/**
 * What the buyer filled in at checkout — a delivery date, a gift message —
 * which the seller needs to ship. Read-only: the buyer's answers are theirs.
 */
export function CheckoutDetailsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const timezone = useStoreTimezone()
  const fields = order.custom_fields ?? []

  if (fields.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('orders.checkout_details.title')}</CardTitle>
      </CardHeader>
      <CardContent>
        <dl className="flex flex-col gap-3">
          {fields.map((field) => (
            <div key={field.id} className="flex flex-col gap-0.5">
              <dt className="text-sm text-muted-foreground">{field.label}</dt>
              <dd className="text-base whitespace-pre-line">
                {formatCustomFieldValue(field.value, field.field_type, timezone)}
              </dd>
            </div>
          ))}
        </dl>
      </CardContent>
    </Card>
  )
}
