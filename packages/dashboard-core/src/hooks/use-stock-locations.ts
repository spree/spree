import type { PaginationMeta } from '@spree/dashboard-ui'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'
import {
  getApiClient,
  type PanelStockLocation,
  type PanelStockLocationCreateParams,
  type PanelStockLocationParams,
} from '../api-client'
import { useResourceKey, useResourceKeyBuilder } from '../lib/query-keys'
import { useResourceMutation } from './use-resource-mutation'

/**
 * The registered panel's stock-location resource.
 *
 * Throws rather than answering undefined: every hook here is only reachable
 * from the stock-locations page, and a panel that routes to it without
 * registering the resource is misconfigured — failing at the call site says
 * so far more clearly than five separate "cannot read property of
 * undefined" errors.
 */
function resource() {
  const stockLocations = getApiClient().stockLocations
  if (!stockLocations) {
    throw new Error(
      '@spree/dashboard-core: this panel registered no `stockLocations` resource, so the ' +
        'stock-locations page cannot load. Add one in setApiClient(), or drop the route.',
    )
  }
  return stockLocations
}

interface UseStockLocationsParams {
  page?: number
  limit?: number
}

// API caps `limit` at 100. The page is configurable so callers with more
// than 100 locations can paginate; the typical merchant has a handful.
export function useStockLocations({ page = 1, limit = 100 }: UseStockLocationsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('stock-locations', { page, limit }),
    queryFn: () => resource().list({ page, limit }),
  })
}

export function useStockLocation(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('stock-locations', id ?? 'noop'),
    queryFn: () => resource().get(id as string),
    enabled: !!id,
  })
}

export function useCreateStockLocation() {
  return useResourceMutation<PanelStockLocation, Error, PanelStockLocationCreateParams>({
    mutationFn: (params) => resource().create(params),
    invalidate: [['stock-locations']],
    successMessage: i18n.t('admin.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateStockLocation(id: string) {
  return useResourceMutation<PanelStockLocation, Error, PanelStockLocationParams>({
    mutationFn: (params) => resource().update(id, params),
    invalidate: [['stock-locations'], ['stock-locations', id]],
    successMessage: i18n.t('admin.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/**
 * Update variant that takes the id per call, for lists where every row writes
 * to a different location (the pickup toggles on a delivery profile).
 */
export function useUpdateStockLocationById() {
  return useResourceMutation<
    PanelStockLocation,
    Error,
    { id: string; params: PanelStockLocationParams }
  >({
    mutationFn: ({ id, params }) => resource().update(id, params),
    invalidate: [['stock-locations']],
    successMessage: i18n.t('admin.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteStockLocation() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    // Guarded: `delete` is optional on the registry, and a panel whose API
    // does not offer it should not render the action at all.
    mutationFn: (id) => {
      const remove = resource().delete
      if (!remove) throw new Error('This panel cannot delete stock locations.')
      return remove(id)
    },
    invalidate: [['stock-locations']],
    successMessage: i18n.t('admin.messages.removed'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      // Drop the individual-resource cache so any open detail view stops
      // showing stale data after the row is gone.
      queryClient.removeQueries({ queryKey: buildKey('stock-locations', id) })
    },
  })
}

/**
 * Whether this panel's API offers deletion at all — the operator's does, a
 * seller's does not. Drives whether the row action is rendered, so a seller
 * is never shown a button that cannot work.
 */
export function canDeleteStockLocations(): boolean {
  return typeof getApiClient().stockLocations?.delete === 'function'
}

/**
 * One page of locations, for `ResourceTable`'s own query. Not a hook — the
 * table calls it with the search params it has already parsed.
 */
export function listStockLocations(params: Record<string, unknown>) {
  return resource().list(params) as Promise<{
    data: PanelStockLocation[]
    meta: PaginationMeta
  }>
}
