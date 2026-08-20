import { useQuery } from '@tanstack/react-query'
import { getApiClient, type PanelCountry } from '../api-client'

/**
 * Countries for the shared address form, through the registered panel client.
 *
 * Deliberately not `adminClient`: this hook backs the one address form both
 * panels use, and importing the operator's client made a seller's country
 * list come back empty — the form rendered, and "No countries found" was the
 * only symptom.
 */
export function useCountries() {
  const { data, isLoading } = useQuery({
    queryKey: ['countries'],
    queryFn: () => getApiClient().listCountries?.() ?? Promise.resolve({ data: [] }),
    staleTime: 1000 * 60 * 30, // 30 minutes — countries rarely change
  })

  const countries: PanelCountry[] = data?.data ?? []

  return { countries, isLoading }
}
