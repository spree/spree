import type { StoreUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  STORE_QUERY_RESOURCE,
  useResourceKey,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

// Reads the same cache entry `<StoreProvider>` maintains — settings pages and
// the provider (nav badge, pickers, Getting Started) always agree.
export function useStoreSettings() {
  return useQuery({
    queryKey: useResourceKey(STORE_QUERY_RESOURCE),
    queryFn: () => adminClient.store.get(),
  })
}

export function useUpdateStoreSettings() {
  return useResourceMutation<unknown, Error, StoreUpdateParams>({
    mutationFn: (params) => adminClient.store.update(params),
    invalidate: [[STORE_QUERY_RESOURCE]],
    successMessage: false,
    errorMessage: false,
  })
}
