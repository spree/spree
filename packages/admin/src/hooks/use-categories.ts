import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useCategories() {
  return useQuery({
    queryKey: ['categories'],
    queryFn: () =>
      adminClient.categories.list({ limit: 100 }),
    staleTime: 1000 * 60 * 5,
  })
}
