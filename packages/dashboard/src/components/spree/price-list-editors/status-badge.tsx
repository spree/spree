import type { PriceList } from '@spree/admin-sdk'
import { StatusBadge } from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

// Colour comes from the shared status map; this component owns only the
// question of *which* status a price list is actually in.
const PRICE_LIST_STATUSES = ['active', 'scheduled', 'inactive', 'draft'] as const

type PriceListStatus = (typeof PRICE_LIST_STATUSES)[number]

function normalizeStatus(value: unknown): PriceListStatus {
  return typeof value === 'string' && (PRICE_LIST_STATUSES as readonly string[]).includes(value)
    ? (value as PriceListStatus)
    : 'draft'
}

export function PriceListStatusBadge({ priceList }: { priceList: PriceList }) {
  const { t } = useTranslation()
  const raw = normalizeStatus(priceList.status)
  // `scheduled` collapses into the active treatment whenever the date
  // range puts it live now. Keep `inactive` distinct even when the API
  // reports a stale `currently_active: true`.
  const status: PriceListStatus = priceList.currently_active && raw !== 'inactive' ? 'active' : raw

  return <StatusBadge status={status} label={t(`admin.fields.price_list.status.${status}`)} />
}
