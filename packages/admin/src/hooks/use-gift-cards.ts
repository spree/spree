import type {
  GiftCard,
  GiftCardBatch,
  GiftCardBatchCreateParams,
  GiftCardCreateParams,
  GiftCardUpdateParams,
} from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const giftCardsQueryKey = ['gift-cards'] as const

export function giftCardQueryKey(id: string, expand?: string[]) {
  return expand?.length ? (['gift-cards', id, { expand }] as const) : (['gift-cards', id] as const)
}

export function useGiftCard(id: string | undefined, expand?: string[]) {
  return useQuery({
    queryKey: id ? giftCardQueryKey(id, expand) : ['gift-cards', 'noop'],
    queryFn: () => adminClient.giftCards.get(id as string, { expand }),
    enabled: !!id,
  })
}

export function listGiftCards(params: Parameters<typeof adminClient.giftCards.list>[0]) {
  return adminClient.giftCards.list(params)
}

export function useCreateGiftCard() {
  return useResourceMutation<GiftCard, Error, GiftCardCreateParams>({
    mutationFn: (params) => adminClient.giftCards.create(params),
    invalidate: [giftCardsQueryKey],
    successMessage: 'Gift card created',
    errorMessage: 'Failed to create gift card',
  })
}

export function useUpdateGiftCard(id: string) {
  return useResourceMutation<GiftCard, Error, GiftCardUpdateParams>({
    mutationFn: (params) => adminClient.giftCards.update(id, params),
    invalidate: [giftCardsQueryKey, giftCardQueryKey(id)],
    successMessage: 'Gift card updated',
    errorMessage: 'Failed to update gift card',
  })
}

export function useDeleteGiftCard() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.giftCards.delete(id),
    invalidate: [giftCardsQueryKey],
    successMessage: 'Gift card deleted',
    errorMessage: 'Failed to delete gift card',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: giftCardQueryKey(id) })
    },
  })
}

// ---------------------------------------------------------------------------
// Batches
// ---------------------------------------------------------------------------

export const giftCardBatchesQueryKey = ['gift-card-batches'] as const

export function useCreateGiftCardBatch() {
  return useResourceMutation<GiftCardBatch, Error, GiftCardBatchCreateParams>({
    mutationFn: (params) => adminClient.giftCardBatches.create(params),
    // Creating a batch generates N cards inline (or kicks off a job for
    // larger batches), so the gift cards list is the surface that needs to
    // refetch — not the batches collection itself.
    invalidate: [giftCardsQueryKey, giftCardBatchesQueryKey],
    successMessage: 'Gift card batch created',
    errorMessage: 'Failed to create gift card batch',
  })
}

/**
 * Shared config for any `<ResourceCombobox>`/`<ResourceMultiAutocomplete>`
 * picking gift card batches (filter chip on the cards table, batch detail
 * lookups). Pass a unique `queryKey` per instance so independent caches
 * don't collide.
 */
export function giftCardBatchAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) =>
      adminClient.giftCardBatches.list({ prefix_cont: q, limit: 20, sort: '-created_at' }),
    hydrate: (ids: string[]) => adminClient.giftCardBatches.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (b: GiftCardBatch) => b.prefix ?? b.id,
    placeholder: 'Search batches by prefix…',
    emptyText: 'No batches match',
  }
}
