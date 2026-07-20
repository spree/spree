import { SpreeError, type StoreUpdateParams } from '@spree/admin-sdk'
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

/**
 * Saves the storefront URL and allows its origin in one step — the action
 * that completes the `setup_storefront` task.
 */
export function useConnectStorefront() {
  return useResourceMutation<string, Error, string>({
    mutationFn: async (origin) => {
      // Origin first: it's idempotent (a 422 means already allowed), and if
      // it fails hard nothing has been persisted yet — whereas saving the URL
      // first and failing here would complete the setup task without CORS
      // access AND skip the invalidation of the already-changed store.
      try {
        await adminClient.allowedOrigins.create({ origin })
      } catch (error) {
        if (!(error instanceof SpreeError) || error.status !== 422) throw error
      }
      await adminClient.store.update({ preferred_storefront_url: origin })
      return origin
    },
    invalidate: [[STORE_QUERY_RESOURCE], ['allowed-origins']],
    successMessage: false,
    errorMessage: false,
  })
}
