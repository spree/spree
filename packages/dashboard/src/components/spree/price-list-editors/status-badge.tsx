import type { PriceList } from '@spree/admin-sdk'
import { Badge } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

// `scheduled` collapses into the active treatment whenever the date
// range puts it live now — mirrors the legacy admin's
// `price_list_status_badge` helper.
const STATUS_STYLES = {
  active: { variant: 'success' as const },
  scheduled: { variant: 'info' as const },
  inactive: { variant: 'secondary' as const },
  draft: { variant: 'outline' as const },
} as const

type PriceListStatus = keyof typeof STATUS_STYLES

function normalizeStatus(value: unknown): PriceListStatus {
  return typeof value === 'string' && value in STATUS_STYLES ? (value as PriceListStatus) : 'draft'
}

export function PriceListStatusBadge({ priceList }: { priceList: PriceList }) {
  const { t } = useTranslation()
  const raw = normalizeStatus(priceList.status)
  // `scheduled` collapses into the active treatment whenever the date
  // range puts it live now. Keep `inactive` distinct even when the API
  // reports a stale `currently_active: true`.
  const status: PriceListStatus = priceList.currently_active && raw !== 'inactive' ? 'active' : raw

  return (
    <Badge variant={STATUS_STYLES[status].variant}>
      {t(`admin.fields.price_list.status.${status}`)}
    </Badge>
  )
}
