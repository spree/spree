import {
  AddressFormDialog,
  editableAddressToStockLocationParams,
  stockLocationToAddressBlock,
  stockLocationToEditableAddress,
} from '@spree/dashboard-core'
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
import { PencilIcon, PlusIcon } from '@spree/dashboard-ui/icons'
import type { StockLocation, StockLocationParams } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

/**
 * Where customers send returns — the address on the seller's default stock
 * location.
 *
 * A location rather than a loose address because returned goods have to be
 * restocked somewhere the catalog can see: stock movements anchor to a
 * location, so an address on its own would leave the parcel arriving nowhere.
 * The seller sees an address form all the same — the location is the record
 * behind it, not a concept they have to learn to fill this in.
 */
export function SellerReturnsLocationCard({ headless = false }: { headless?: boolean }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)

  const { data: locations } = useQuery({
    queryKey: ['seller', sellerId, 'stock-locations'],
    queryFn: () => sellerClient().stockLocations.list({ per_page: 100 }),
  })

  // Must match `Seller#returns_location` exactly: among active locations,
  // one that accepts returns wins outright, and only then does default and
  // name decide. Ignoring either tier would present one location as the
  // returns address while the server sent returns to another, with nothing
  // on screen saying so — and the seller would edit the wrong address.
  const byDefaultThenName = (a: StockLocation, b: StockLocation) =>
    Number(b.default) - Number(a.default) || a.name.localeCompare(b.name)
  const active = (locations?.data ?? [])
    .filter((candidate) => candidate.active)
    .sort(byDefaultThenName)
  const location = active.find((candidate) => candidate.returns_enabled) ?? active[0]
  const hasAddress = Boolean(location?.address1)
  const title = t('profile.returns_address')

  const save = useMutation({
    mutationFn: (params: StockLocationParams) => {
      if (!location) throw new Error(t('common.error'))
      return sellerClient().stockLocations.update(location.id, params)
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'stock-locations'] })
      // The checklist asks whether this address is filled in, so it has to
      // re-evaluate.
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

  const body =
    hasAddress && location ? (
      <AddressBlock address={stockLocationToAddressBlock(location)} />
    ) : (
      <p className="text-muted-foreground text-sm">{t('profile.address_not_provided')}</p>
    )

  const editButton = (
    <Button
      variant={hasAddress ? 'outline' : 'default'}
      size="sm"
      disabled={!location}
      onClick={() => setEditing(true)}
    >
      {hasAddress ? <PencilIcon className="size-4" /> : <PlusIcon className="size-4" />}
      {hasAddress ? t('profile.edit') : t('profile.add_address')}
    </Button>
  )

  const dialog = editing && location && (
    <AddressFormDialog
      title={title}
      address={stockLocationToEditableAddress(location)}
      open
      business
      onOpenChange={setEditing}
      onSave={(values) => save.mutate(editableAddressToStockLocationParams(values))}
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
            {hasAddress ? (
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
