import type { Seller } from '@spree/admin-sdk'
import { AddressFormDialog } from '@spree/dashboard-core'
import {
  AddressBlock,
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
} from '@spree/dashboard-ui'
import { PencilIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateSeller } from '../../../hooks/use-sellers'
import { SellerAddressMap } from './seller-address-map'

type AddressKey = 'billing_address' | 'returns_address'

/**
 * One of a seller's two addresses — where they are invoiced, and where
 * customer returns go — with the map the legacy admin showed beside it.
 *
 * A returns address is what a shopper is told to post to, and a billing
 * address is what a commission invoice is addressed to, so both are worth
 * seeing on a map rather than trusting as typed.
 *
 * Only the billing address is editable here. A seller's returns address is
 * derived from their default stock location, so it is written through that
 * location in the seller panel — an edit dialog on this card would PATCH a
 * key the API does not permit, close, and quietly save nothing.
 */
export function SellerAddressCard({
  seller,
  addressKey,
  canEdit,
}: {
  seller: Seller
  addressKey: AddressKey
  canEdit: boolean
}) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState(false)
  const updateMutation = useUpdateSeller(seller.id)
  const address = seller[addressKey]
  const title = t(`admin.sellers.detail.${addressKey}`)
  const editable = canEdit && addressKey === 'billing_address'

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {title}
            {address ? (
              <Badge variant="success">{t('admin.sellers.address.filled')}</Badge>
            ) : (
              <Badge variant="outline">{t('admin.sellers.address.not_filled')}</Badge>
            )}
          </CardTitle>
          {editable && (
            <CardAction>
              <Button
                variant="ghost"
                size="icon-sm"
                onClick={() => setEditing(true)}
                aria-label={t('admin.actions.edit')}
              >
                <PencilIcon className="size-4" />
              </Button>
            </CardAction>
          )}
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          {address ? (
            <>
              {/* No title: the card header already names it. */}
              <AddressBlock address={address} />
              <SellerAddressMap address={address} label={seller.name} />
            </>
          ) : (
            <p className="py-4 text-center text-muted-foreground text-sm">
              {t('admin.sellers.address.not_provided_by_seller')}
            </p>
          )}
        </CardContent>
      </Card>

      {editing && (
        <AddressFormDialog
          title={title}
          address={address}
          open
          // A seller is invoiced as a company, matching what the API requires.
          business
          onOpenChange={setEditing}
          // Only the address being edited is sent: the other one is untouched,
          // and posting both would rewrite a record the operator never opened.
          onSave={async (values) => {
            await updateMutation.mutateAsync({ [addressKey]: values })
            setEditing(false)
          }}
          isPending={updateMutation.isPending}
        />
      )}
    </>
  )
}
