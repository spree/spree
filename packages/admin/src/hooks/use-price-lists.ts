import type { PriceList, PriceListCreateParams, PriceListUpdateParams } from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const priceListsQueryKey = ['price-lists'] as const

export function priceListQueryKey(id: string, expand?: string[]) {
  return expand?.length
    ? (['price-lists', id, { expand }] as const)
    : (['price-lists', id] as const)
}

export function usePriceList(id: string | undefined, expand?: string[]) {
  return useQuery({
    queryKey: id ? priceListQueryKey(id, expand) : ['price-lists', 'noop'],
    queryFn: () => adminClient.priceLists.get(id as string, { expand }),
    enabled: !!id,
  })
}

export function useCreatePriceList() {
  return useResourceMutation<PriceList, Error, PriceListCreateParams>({
    mutationFn: (params) => adminClient.priceLists.create(params),
    invalidate: [priceListsQueryKey],
    successMessage: 'Price list created',
    errorMessage: 'Failed to create price list',
  })
}

export function useUpdatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, PriceListUpdateParams>({
    mutationFn: (params) => adminClient.priceLists.update(id, params),
    invalidate: [priceListsQueryKey, priceListQueryKey(id)],
    successMessage: 'Price list updated',
    errorMessage: 'Failed to update price list',
  })
}

export function useDeletePriceList() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.priceLists.delete(id),
    invalidate: [priceListsQueryKey],
    successMessage: 'Price list deleted',
    errorMessage: 'Failed to delete price list',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: priceListQueryKey(id) })
    },
  })
}

export function useActivatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, void>({
    mutationFn: () => adminClient.priceLists.activate(id),
    invalidate: [priceListsQueryKey, priceListQueryKey(id)],
    successMessage: 'Price list activated',
    errorMessage: 'Failed to activate price list',
  })
}

export function useDeactivatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, void>({
    mutationFn: () => adminClient.priceLists.deactivate(id),
    invalidate: [priceListsQueryKey, priceListQueryKey(id)],
    successMessage: 'Price list deactivated',
    errorMessage: 'Failed to deactivate price list',
  })
}

// Prices ride along on `useUpdatePriceList` — there's no separate
// mutation hook for the spreadsheet anymore.

// ---------------------------------------------------------------------------
// Price Rule type discovery
// ---------------------------------------------------------------------------
//
// Rules themselves aren't a separate REST resource — the SPA ships them
// inline on the price list `update` payload via `rules: [...]`. The
// `ruleTypes` lookup below is the one piece of separately-fetched data
// the rule editor needs: the registry of available subclasses (and their
// `preference_schema`) so the "Add rule" picker + generic preferences
// form know what to render.

const priceRuleTypesQueryKey = ['price-rule-types'] as const

export function usePriceRuleTypes() {
  return useQuery({
    queryKey: priceRuleTypesQueryKey,
    queryFn: () => adminClient.priceLists.ruleTypes(),
    // Registry is static; cache for the session.
    staleTime: Infinity,
  })
}
