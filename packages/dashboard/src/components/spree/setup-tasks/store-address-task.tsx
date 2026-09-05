import {
  AddressFormDialog,
  adminClient,
  editableAddressToStockLocationParams,
  STORE_QUERY_RESOURCE,
  stockLocationToAddressBlock,
  stockLocationToEditableAddress,
  useResourceKey,
  useUpdateStockLocationById,
} from '@spree/dashboard-core'
import { AddressBlock, Button, Skeleton } from '@spree/dashboard-ui'
import { PencilIcon, PlusIcon } from '@spree/dashboard-ui/icons'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { SetupTaskSlotContext } from './types'

/**
 * Card body for the setup_address task: the merchant's own shipping and
 * returns address.
 *
 * The address is written to the store's default stock location, not to the
 * store — `Spree::Store#address` is a free-text blob for the email footer,
 * while carriers rating a parcel need the structured columns a location
 * carries. That is the same record returns route to, so asking once covers
 * both.
 *
 * The same dialog the seller panel edits its returns address with, against
 * the operator's own location — so the two panels cannot drift on what a
 * complete address is.
 */
export function StoreAddressTask({ task }: SetupTaskSlotContext) {
  const { t } = useTranslation()
  const queryClient = useQueryClient()
  const [editing, setEditing] = useState(false)
  const update = useUpdateStockLocationById()

  // Filtered server-side rather than by paging the whole list: on a
  // marketplace this collection also holds every seller's warehouse, and a
  // seller's row is commonly their own default — so the operator's own
  // location can sit past the first page and vanish from a client-side filter.
  const { data: locations, isLoading } = useQuery({
    queryKey: useResourceKey('stock-locations', { firstParty: true }),
    queryFn: () =>
      // The controller already orders default-first then by name.
      adminClient.stockLocations.list({ seller_id_null: true, active_true: true, limit: 20 }),
  })

  // Must match `Store#primary_location`: one that accepts returns wins, and
  // only then default and name decide. Pointing the merchant at any other row
  // would have them fill in an address their parcels never come back to.
  const firstParty = locations?.data ?? []
  const location = firstParty.find((candidate) => candidate.returns_enabled) ?? firstParty[0]

  const hasAddress = Boolean(location?.address1)

  return (
    <>
      <p className="text-muted-foreground text-sm">
        {t('admin.pages.getting_started.tasks.setup_address.description')}
      </p>

      {isLoading ? (
        <Skeleton className="h-9 w-64" />
      ) : location ? (
        <>
          {hasAddress && <AddressBlock address={stockLocationToAddressBlock(location)} />}
          <Button variant={task.done ? 'outline' : 'default'} onClick={() => setEditing(true)}>
            {hasAddress ? <PencilIcon className="size-4" /> : <PlusIcon className="size-4" />}
            {t('admin.pages.getting_started.tasks.setup_address.cta')}
          </Button>
        </>
      ) : (
        <p className="text-muted-foreground text-sm">
          {t('admin.pages.getting_started.tasks.setup_address.no_location')}
        </p>
      )}

      {editing && location && (
        <AddressFormDialog
          title={t('admin.pages.getting_started.tasks.setup_address.title')}
          address={stockLocationToEditableAddress(location)}
          open
          business
          onOpenChange={setEditing}
          onSave={async (values) => {
            await update.mutateAsync({
              id: location.id,
              params: editableAddressToStockLocationParams(values),
            })
            // The checklist reads this address off the store payload, so the
            // tick and the nav badge only move once the store is re-read.
            await queryClient.invalidateQueries({ queryKey: [STORE_QUERY_RESOURCE] })
            setEditing(false)
          }}
          isPending={update.isPending}
        />
      )}
    </>
  )
}
