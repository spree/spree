import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useTaxons() {
  return useQuery({
    queryKey: ['taxons'],
    queryFn: () =>
      adminClient.taxons.list({ limit: 100, expand: ['taxonomy'] }),
    staleTime: 1000 * 60 * 5,
  })
}
