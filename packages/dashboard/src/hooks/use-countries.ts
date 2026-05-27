import type { Country } from '@spree/admin-sdk'
import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useCountries() {
  const { data, isLoading } = useQuery({
    queryKey: ['countries'],
    queryFn: () => adminClient.countries.list({ expand: ['states'] }),
    staleTime: 1000 * 60 * 30, // 30 minutes — countries rarely change
  })

  const countries: Country[] = data?.data ?? []

  return { countries, isLoading }
}
