import type { Seller } from '@spree/admin-sdk'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  RelativeTime,
} from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { ReadRow } from './seller-read-row'

/** Operator-only: how and when this seller gets paid, and who remits tax. */
export function SellerSettlementCard({
  seller,
  canEdit,
  onEdit,
}: {
  seller: Seller
  canEdit: boolean
  onEdit: () => void
}) {
  const { t } = useTranslation()

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.sellers.detail.settlement')}</CardTitle>
        {canEdit && (
          <CardAction>
            <Button
              variant="ghost"
              size="icon-sm"
              onClick={onEdit}
              aria-label={t('admin.actions.edit')}
            >
              <PencilIcon className="size-4" />
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        <ReadRow label={t('admin.fields.seller.tax_remittance.label')}>
          {t(`admin.sellers.tax_remittance.${seller.tax_remittance}`, {
            defaultValue: seller.tax_remittance,
          })}
        </ReadRow>
        <ReadRow label={t('admin.fields.seller.payouts_schedule_interval.label')}>
          {seller.payouts_schedule_interval
            ? t(`admin.sellers.payout_interval.${seller.payouts_schedule_interval}`)
            : t('admin.sellers.payout_interval.inherit')}
        </ReadRow>
        <ReadRow label={t('admin.fields.seller.minimum_payout_amount.label')}>
          {seller.minimum_payout_amount}
        </ReadRow>
        <ReadRow label={t('admin.fields.seller.holiday_mode_until.label')}>
          {seller.holiday_mode_until ? <RelativeTime iso={seller.holiday_mode_until} /> : null}
        </ReadRow>
      </CardContent>
    </Card>
  )
}
