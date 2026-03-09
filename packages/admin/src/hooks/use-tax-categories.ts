import { useQuery } from '@tanstack/react-query'
import { spreeClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

export function useTaxCategories() {
  const { token } = useAuth()

  return useQuery({
    queryKey: ['tax-categories'],
    queryFn: () => spreeClient.admin.taxCategories.list({}, { token: token! }),
    enabled: !!token,
    staleTime: 1000 * 60 * 5,
  })
}
