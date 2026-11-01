import type { Seller } from '@spree/admin-sdk'
import { Card, CardContent, CardHeader, CardTitle, RelativeTime } from '@spree/dashboard-ui'
import { PackageIcon, ReceiptTextIcon, UsersIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { useSellerMissingInvoicesCount } from '../../../hooks/use-invoices'
import { ReadRow } from './seller-read-row'

/** The counts an operator scans for before opening anything else. */
export function SellerAtAGlanceCard({ seller }: { seller: Seller }) {
  const { t } = useTranslation()
  const { data: missingInvoices } = useSellerMissingInvoicesCount(seller.id)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.detail.at_a_glance')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <div className="flex items-center justify-between text-sm">
          <span className="flex items-center gap-2 text-muted-foreground">
            <PackageIcon className="size-4" />
            {t('admin.sellers.products_column')}
          </span>
          <span>{seller.products_count}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
          <span className="flex items-center gap-2 text-muted-foreground">
            <UsersIcon className="size-4" />
            {t('admin.sellers.team_column')}
          </span>
          <span>{seller.users_count}</span>
        </div>
        <div className="flex items-center justify-between text-sm">
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
