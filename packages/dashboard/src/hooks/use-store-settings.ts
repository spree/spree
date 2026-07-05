import type { StoreUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation, useStore } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useStoreSettings() {
  return useQuery({
    queryKey: useResourceKey('store-settings'),
    queryFn: () => adminClient.store.get(),
  })
}

export function useUpdateStoreSettings() {
  const { refetch } = useStore()
  return useResourceMutation<unknown, Error, StoreUpdateParams>({
    mutationFn: (params) => adminClient.store.update(params),
    invalidate: [['store-settings']],
    successMessage: false,
    errorMessage: false,
    onSuccess: () => {
      refetch()
    },
  })
}
