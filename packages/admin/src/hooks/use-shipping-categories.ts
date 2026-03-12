import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useShippingCategories() {
  return useQuery({
    queryKey: ['shipping-categories'],
    queryFn: () => adminClient.shippingCategories.list(),
    staleTime: 1000 * 60 * 5,
  })
}
