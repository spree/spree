import type { Seller } from '@spree/admin-sdk'
import { AddressFormDialog } from '@spree/dashboard-core'
import { AddressBlock, Button } from '@spree/dashboard-ui'
import { PencilIcon } from '@spree/dashboard-ui/icons'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useUpdateSeller } from '../../../hooks/use-sellers'

type AddressKey = 'billing_address' | 'returns_address'

/**
 * One of a seller's two addresses — where they are invoiced, and where
 * customer returns go. A returns address is what a shopper is told to post
 * to, and a billing address is what a commission invoice is addressed to.
 *
 * Rendered inside the contact card, under the seller's emails, and both are
 * edited here. The returns address is the seller's returns stock location's
 * own; the API writes it onto that location, or makes one if there is none.
 */
export function SellerAddress({
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
    <div className="flex flex-col gap-1.5">
      <div className="flex min-h-7 items-center justify-between gap-2">
        <h3 className="font-medium text-base">{title}</h3>
        {canEdit && (
          <Button
            variant="ghost"
            size="icon-sm"
            onClick={() => setEditing(true)}
            aria-label={t('admin.actions.edit')}
          >
            <PencilIcon className="size-4" />
          </Button>
        )}
      </div>
      <AddressBlock
        address={address}
        emptyText={t('admin.sellers.address.not_provided_by_seller')}
      />

      {editing && (
        <AddressFormDialog
          title={title}
          address={address}
          open
          // Both are addressed to the business: a seller is invoiced as a
          // company, and returns are posted to one.
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
    </div>
  )
}
