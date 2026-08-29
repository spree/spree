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
  StatusBadge,
  toastManager,
} from '@spree/dashboard-ui'
import type { Profile, SellerAddressParams } from '@spree/seller-sdk'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { PencilIcon, PlusIcon } from 'lucide-react'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

/**
 * Where the seller is invoiced — read as a block, edited in the shared
 * address dialog.
 *
 * Used both on the profile page and inline in the onboarding checklist, so a
 * seller working through setup fills the address where they are told about
 * it rather than being sent somewhere else and losing their place. Same
 * component either way, so the two can never diverge.
 *
 * Returns are not here: they go to a stock location, which is a record of its
 * own — see `SellerReturnsLocationCard`.
 */
export function SellerAddressCard({
  profile,
  headless = false,
}: {
  profile: Profile
  /** Render just the body — the onboarding checklist supplies its own frame. */
  headless?: boolean
}) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)

  const address = profile.billing_address
  const title = t('profile.billing_address')

  const save = useMutation({
    // Only the billing address is sent: the rest of the profile is untouched,
    // and posting it all would rewrite fields the seller never opened.
    mutationFn: (values: SellerAddressParams) =>
      sellerClient().profile.update({ billing_address: values }),
    onSuccess: (updated) => {
      queryClient.setQueryData(['seller', sellerId, 'profile'], updated)
      // The checklist reads addresses too, so it has to re-evaluate.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
      setEditing(false)
      toastManager.add({ type: 'success', title: t('profile.saved') })
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('common.error'),
      }),
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
      business
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
              <StatusBadge status="complete" label={t('profile.address_filled')} />
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
