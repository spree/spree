import type { Seller } from '@spree/admin-sdk'
import { Button, Card, CardAction, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { ReadRow } from './seller-read-row'

export function SellerContactCard({
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
        <CardTitle>{t('admin.sellers.detail.contact')}</CardTitle>
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
        <ReadRow label={t('admin.fields.contact_email.label')}>
          {seller.contact_email ? (
            <a href={`mailto:${seller.contact_email}`}>{seller.contact_email}</a>
          ) : null}
        </ReadRow>
        <ReadRow label={t('admin.fields.seller.billing_email.label')}>
          {seller.billing_email ? (
            <a href={`mailto:${seller.billing_email}`}>{seller.billing_email}</a>
          ) : null}
        </ReadRow>
      </CardContent>
    </Card>
  )
}
