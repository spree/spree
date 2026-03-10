import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useTaxCategories() {
  return useQuery({
    queryKey: ['tax-categories'],
    queryFn: () => adminClient.taxCategories.list(),
    staleTime: 1000 * 60 * 5,
  })
}
