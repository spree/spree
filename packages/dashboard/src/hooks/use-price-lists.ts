import type { PriceList, PriceListCreateParams, PriceListUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

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
    successMessage: i18n.t('admin.products.price_lists.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, PriceListUpdateParams>({
    mutationFn: (params) => adminClient.priceLists.update(id, params),
    // The nested products list is held back: it prefix-matches
    // `['price-lists', id]`, and this update runs before the membership flush
    // inside the page's Save — refreshing it there paints the pre-save rows
    // for a frame. The flush refreshes it once, at the end.
    invalidate: [['price-lists'], ['price-lists', id]],
    doNotInvalidate: ['products'],
    successMessage: i18n.t('admin.products.price_lists.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeletePriceList() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.priceLists.delete(id),
    invalidate: [['price-lists']],
    successMessage: i18n.t('admin.products.price_lists.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('price-lists', id) })
    },
  })
}

export function useActivatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, void>({
    mutationFn: () => adminClient.priceLists.activate(id),
    invalidate: [['price-lists'], ['price-lists', id]],
    successMessage: i18n.t('admin.products.price_lists.messages.activated'),
    errorMessage: i18n.t('admin.products.price_lists.errors.failed_to_activate'),
  })
}

export function useDeactivatePriceList(id: string) {
  return useResourceMutation<PriceList, Error, void>({
    mutationFn: () => adminClient.priceLists.deactivate(id),
    invalidate: [['price-lists'], ['price-lists', id]],
    successMessage: i18n.t('admin.products.price_lists.messages.deactivated'),
    errorMessage: i18n.t('admin.products.price_lists.errors.failed_to_deactivate'),
  })
}

// ---------------------------------------------------------------------------
// Product membership — the uniform nested surface, staged in the editor and
// flushed on Save (deferred card).
// ---------------------------------------------------------------------------

export function usePriceListProducts(priceListId: string | undefined, page = 1) {
  return useQuery({
    queryKey: useResourceKey('price-lists', priceListId ?? 'noop', 'products', `${page}`),
    queryFn: () => listPriceListProductsPage(priceListId as string, page),
    enabled: !!priceListId,
    placeholderData: (previous) => previous,
  })
}

/** Paginated price-list membership fetch for picker exclusion. */
export function listPriceListProductsPage(priceListId: string, page: number, limit = 100) {
  return adminClient.priceLists.products.list(priceListId, { page, limit })
}

// Both flush mutations stay silent — they run inside the editor's Save,
// whose update mutation already reports the outcome.

export function useAddPriceListProducts(priceListId: string) {
  return useResourceMutation<{ added_count: number }, Error, string[]>({
    mutationFn: (productIds) => adminClient.priceLists.products.create(priceListId, productIds),
    // No invalidate: the flush refreshes the list once, after every write.
    successMessage: false,
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRemovePriceListProducts(priceListId: string) {
  return useResourceMutation<{ removed_count: number }, Error, string[]>({
    mutationFn: (productIds) => adminClient.priceLists.products.delete(priceListId, productIds),
    // No invalidate: the flush refreshes the list once, after every write.
    successMessage: false,
    errorMessage: i18n.t('admin.errors.failed_to_update'),
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
