import type { Seller } from '@spree/admin-sdk'
import { Card, CardContent, CardHeader, CardTitle, RelativeTime } from '@spree/dashboard-ui'
import { PackageIcon, UsersIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { ReadRow } from '../read-row'

/**
 * Where the seller stands in plain words, and the counts an operator scans
 * for before opening anything else. The status itself is the badge in the
 * page header; this says what it means.
 */
export function SellerAtAGlanceCard({ seller }: { seller: Seller }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.detail.at_a_glance')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <p className="text-muted-foreground text-sm">
          {t(`admin.sellers.status_help.${seller.status}`, {
            defaultValue: t('admin.sellers.status_help.pending'),
          })}
          {seller.on_holiday && ` ${t('admin.sellers.on_holiday_notice')}`}
        </p>
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
        <ReadRow label={t('admin.fields.created_at.label')}>
          <RelativeTime iso={seller.created_at} />
        </ReadRow>
      </CardContent>
    </Card>
  )
}
