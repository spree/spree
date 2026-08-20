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
import type { Profile } from '@spree/seller-sdk'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { PencilIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { sellerClient } from '../api-client'

export type SellerAddressKey = 'billing_address' | 'returns_address'

/**
 * One of the seller's two addresses — where they are invoiced, and where
 * customer returns go — read as a block, edited in the shared address dialog.
 *
 * Used both on the profile page and inline in the onboarding checklist, so a
 * seller working through setup fills the address where they are told about
 * it rather than being sent somewhere else and losing their place. Same
 * component either way, so the two can never diverge.
 */
export function SellerAddressCard({
  profile,
  addressKey,
  headless = false,
}: {
  profile: Profile
  addressKey: SellerAddressKey
  /** Render just the body — the onboarding checklist supplies its own frame. */
  headless?: boolean
}) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)

  const address = profile[addressKey]
  const title = t(`profile.${addressKey}`)

  const save = useMutation({
    // Only the address being edited is sent: the other is untouched, and
    // posting both would rewrite a record the seller never opened.
    mutationFn: (values: unknown) => sellerClient().profile.update({ [addressKey]: values }),
    onSuccess: (updated) => {
      queryClient.setQueryData(['seller', sellerId, 'profile'], updated)
      // The checklist reads addresses too, so it has to re-evaluate.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
      setEditing(false)
      toast.success(t('profile.saved'))
    },
    onError: (err) => toast.error(err instanceof Error ? err.message : t('common.error')),
  })

  const body = address ? (
    <AddressBlock address={address} />
  ) : (
    <p className="text-muted-foreground text-sm">{t('profile.address_not_provided')}</p>
  )

  const editButton = (
    <Button variant={address ? 'outline' : 'default'} size="sm" onClick={() => setEditing(true)}>
      {address ? <PencilIcon className="size-4" /> : <PlusIcon className="size-4" />}
      {address ? t('profile.edit') : t('profile.add_address')}
    </Button>
  )

  const dialog = editing && (
    <AddressFormDialog
      title={title}
      address={address}
      open
      onOpenChange={setEditing}
      onSave={(values) => save.mutate(values)}
      isPending={save.isPending}
    />
  )

  if (headless) {
    return (
      <div className="flex flex-col items-start gap-3">
        {body}
        {editButton}
        {dialog}
      </div>
    )
  }

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {title}
            {address ? (
              <Badge variant="success">{t('profile.address_filled')}</Badge>
            ) : (
              <Badge variant="outline">{t('profile.address_missing')}</Badge>
            )}
          </CardTitle>
          <CardAction>{editButton}</CardAction>
        </CardHeader>
        <CardContent>{body}</CardContent>
      </Card>
      {dialog}
    </>
  )
}
