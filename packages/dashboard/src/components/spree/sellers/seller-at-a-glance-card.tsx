import type { Seller } from '@spree/admin-sdk'
import { useStore } from '@spree/dashboard-core'
import { Card, CardContent, CardHeader, CardTitle, RelativeTime } from '@spree/dashboard-ui'
import { PackageIcon, ReceiptTextIcon, UsersIcon, WarehouseIcon } from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useSellerMissingInvoicesCount } from '../../../hooks/use-invoices'
import { ReadRow } from '../read-row'

/**
 * Where the seller stands in plain words, and the counts an operator scans
 * for before opening anything else. The status itself is the badge in the
 * page header; this says what it means.
 */
export function SellerAtAGlanceCard({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const { data: missingInvoices } = useSellerMissingInvoicesCount(seller.id)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.detail.at_a_glance')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <p className="text-muted-foreground text-base">
          {t(`admin.sellers.status_help.${seller.status}`, {
            defaultValue: t('admin.sellers.status_help.pending'),
          })}
          {seller.on_holiday && ` ${t('admin.sellers.on_holiday_notice')}`}
        </p>
        <div className="flex items-center justify-between text-base">
          <span className="flex items-center gap-2 text-muted-foreground">
            <PackageIcon className="size-4" />
            {t('admin.sellers.products_column')}
          </span>
          <span>{seller.products_count}</span>
        </div>
        <div className="flex items-center justify-between text-base">
          <span className="flex items-center gap-2 text-muted-foreground">
            <UsersIcon className="size-4" />
            {t('admin.sellers.team_column')}
          </span>
          <span>{seller.users_count}</span>
        </div>
        <div className="flex items-center justify-between text-base">
          <span className="flex items-center gap-2 text-muted-foreground">
            <WarehouseIcon className="size-4" />
            {t('admin.settings_nav.items.stock_locations')}
          </span>
          <Link
            to="/$storeId/settings/stock-locations"
            params={{ storeId }}
            search={
              {
                view: 'sellers',
                filters: JSON.stringify([
                  { id: 'seller', field: 'seller_id', operator: 'in', value: seller.id },
                ]),
              } as never
            }
            className="text-link hover:text-link-hover"
          >
            {t('admin.actions.view')}
          </Link>
        </div>
        <div className="flex items-center justify-between text-base">
          <span className="flex items-center gap-2 text-muted-foreground">
            <ReceiptTextIcon className="size-4" />
            {t('admin.sellers.missing_invoices')}
          </span>
          <span data-testid="seller-missing-invoices">{missingInvoices ?? '—'}</span>
        </div>
        <ReadRow label={t('admin.fields.created_at.label')}>
          <RelativeTime iso={seller.created_at} />
        </ReadRow>
      </CardContent>
    </Card>
  )
}
