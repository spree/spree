import type { StoreUpdateParams } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useStore } from '@/providers/store-provider'

export function useStoreSettings() {
  return useQuery({
    queryKey: ['store-settings'],
    queryFn: () => adminClient.store.get(),
  })
}

export function useUpdateStoreSettings() {
  const queryClient = useQueryClient()
  const { refetch } = useStore()

  return useMutation({
    mutationFn: (params: StoreUpdateParams) => adminClient.store.update(params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['store-settings'] })
      refetch()
    },
  })
}
