import { useQuery } from '@tanstack/react-query'
import { spreeClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

export function useTaxons() {
  const { token } = useAuth()

  return useQuery({
    queryKey: ['taxons'],
    queryFn: () =>
      spreeClient.admin.taxons.list(
        { limit: 100, expand: ['taxonomy'] },
        { token: token! },
      ),
    enabled: !!token,
    staleTime: 1000 * 60 * 5,
  })
}
