import type { PriceList, PriceListCreateParams, PriceListUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

export function usePriceList(id: string | undefined, expand?: string[]) {
  const base = useResourceKey('price-lists', id ?? 'noop')
  return useQuery({
    queryKey: expand?.length ? [...base, { expand }] : base,
    queryFn: () => adminClient.priceLists.get(id as string, { expand }),
    enabled: !!id,
  })
}

export function useCreatePriceList() {
  return useResourceMutation<PriceList, Error, PriceListCreateParams>({
    mutationFn: (params) => adminClient.priceLists.create(params),
    invalidate: [['price-lists']],
    successMessage: 'Price list created',
    errorMessage: 'Failed to create price list',
  })
}

export function useUpdatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, PriceListUpdateParams>({
    mutationFn: (params) => adminClient.priceLists.update(id, params),
    invalidate: [['price-lists'], ['price-lists', id]],
    successMessage: 'Price list updated',
    errorMessage: 'Failed to update price list',
  })
}

export function useDeletePriceList() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.priceLists.delete(id),
    invalidate: [['price-lists']],
    successMessage: 'Price list deleted',
    errorMessage: 'Failed to delete price list',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('price-lists', id) })
    },
  })
}

export function useActivatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, void>({
    mutationFn: () => adminClient.priceLists.activate(id),
    invalidate: [['price-lists'], ['price-lists', id]],
    successMessage: 'Price list activated',
    errorMessage: 'Failed to activate price list',
  })
}

export function useDeactivatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, void>({
    mutationFn: () => adminClient.priceLists.deactivate(id),
    invalidate: [['price-lists'], ['price-lists', id]],
    successMessage: 'Price list deactivated',
    errorMessage: 'Failed to deactivate price list',
  })
}

// Prices ride along on `useUpdatePriceList` — there's no separate
// mutation hook for the spreadsheet anymore.

// ---------------------------------------------------------------------------
// Price Rule type discovery — registry is static, no store scope needed.
// ---------------------------------------------------------------------------

export function usePriceRuleTypes() {
  return useQuery({
    queryKey: ['price-rule-types'],
    queryFn: () => adminClient.priceLists.ruleTypes(),
    staleTime: Infinity,
  })
}
