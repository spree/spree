import type { Seller } from '@spree/admin-sdk'
import { Button, Card, CardAction, CardContent, CardHeader, CardTitle } from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import { useTranslation } from 'react-i18next'
import { ReadRow } from '../read-row'
import { SellerAddress } from './seller-address-card'

/**
 * How the marketplace reaches the seller: their emails, then the addresses an
 * invoice and a customer return are sent to. The pencil edits the emails;
 * the billing address has its own.
 */
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
      <CardContent className="flex flex-col gap-4">
        <div className="flex flex-col gap-3">
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
        </div>
        <div className="border-border-subtle border-t pt-4">
          <SellerAddress seller={seller} addressKey="billing_address" canEdit={canEdit} />
        </div>
        <div className="border-border-subtle border-t pt-4">
          <SellerAddress seller={seller} addressKey="returns_address" canEdit={canEdit} />
        </div>
      </CardContent>
    </Card>
  )
}
