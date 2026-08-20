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
          {canEdit && (
            <CardAction>
              <Button variant="outline" size="sm" onClick={() => setEditing(true)}>
                <PencilIcon className="size-4" />
                {t('admin.actions.edit')}
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
