import { adminClient } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useStoreCreditCategories() {
  return useQuery({
    queryKey: ['store-credit-categories'],
    queryFn: () => adminClient.storeCreditCategories.list(),
    staleTime: 1000 * 60 * 5,
  })
}
