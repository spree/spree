import { useQuery } from '@tanstack/react-query'
import { spreeClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

export function useShippingCategories() {
  const { token } = useAuth()

  return useQuery({
    queryKey: ['shipping-categories'],
    queryFn: () => spreeClient.admin.shippingCategories.list({}, { token: token! }),
    enabled: !!token,
    staleTime: 1000 * 60 * 5,
  })
}
