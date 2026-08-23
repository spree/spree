import type { Seller } from '@spree/admin-sdk'
import {
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  StatusBadge,
} from '@spree/dashboard-ui'
import { useTranslation } from 'react-i18next'

/** Where the seller is, and what that means in plain words. */
export function SellerStatusCard({ seller }: { seller: Seller }) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.detail.status')}</CardTitle>
        <CardAction>
          <StatusBadge status={seller.status} label={t(`admin.sellers.status.${seller.status}`)} />
        </CardAction>
      </CardHeader>
      <CardContent className="flex flex-col gap-2">
        <p className="text-muted-foreground text-sm">
          {t(`admin.sellers.status_help.${seller.status}`, {
            defaultValue: t('admin.sellers.status_help.pending'),
          })}
        </p>
        {seller.on_holiday && (
          <p className="text-muted-foreground text-sm">{t('admin.sellers.on_holiday_notice')}</p>
        )}
      </CardContent>
    </Card>
  )
}
