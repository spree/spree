import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useStoreCreditCategories() {
  return useQuery({
    queryKey: ['store-credit-categories'],
    queryFn: () => adminClient.storeCreditCategories.list(),
    staleTime: 1000 * 60 * 5,
  })
}
