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

  // Two filtered requests rather than one page filtered in the browser, to
  // match `Store#primary_location` exactly: a location that accepts returns
  // wins outright, and only then default and name decide. The list also holds
  // every seller's warehouse on a marketplace, so the operator's own
  // returns-enabled row can sit well past any page we could fetch — and
  // editing the wrong one means an address their parcels never come back to.
  //
  // The list endpoint cannot express the preference in one call: it orders by
  // default then name, and its `sort` param collapses to a single key.
  const firstParty = { seller_id_null: true, active_true: true, limit: 1 }
  const {
    data: takesReturns,
    isFetching: fetchingReturns,
    isError: returnsFailed,
  } = useQuery({
    queryKey: useResourceKey('stock-locations', { firstParty: true, returns: true }),
    queryFn: () => adminClient.stockLocations.list({ ...firstParty, returns_enabled_true: true }),
  })
  const hasReturnsLocation = (takesReturns?.data.length ?? 0) > 0
  const {
    data: anyActive,
    isFetching: fetchingAny,
    isError: anyFailed,
  } = useQuery({
    queryKey: useResourceKey('stock-locations', { firstParty: true }),
    queryFn: () => adminClient.stockLocations.list(firstParty),
    enabled: !!takesReturns && !hasReturnsLocation,
  })

  // `isFetching`, not `isLoading`: a disabled query stays pending forever, so
  // the fallback request would hold the skeleton open once the first one hit.
  const isLoading = fetchingReturns || fetchingAny
  const location = takesReturns?.data[0] ?? anyActive?.data[0]
  // A failed lookup must not read as "you have no warehouse" — that would
  // send the merchant off to create a second one they do not need.
  const failed = returnsFailed || anyFailed

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
        <p className={failed ? 'text-destructive text-sm' : 'text-muted-foreground text-sm'}>
          {t(
            failed
              ? 'admin.errors.failed_to_load'
              : 'admin.pages.getting_started.tasks.setup_address.no_location',
          )}
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
