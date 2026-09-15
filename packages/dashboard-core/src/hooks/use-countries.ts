import { useQuery } from '@tanstack/react-query'
import { getApiClient, type PanelCountry } from '../api-client'

/**
 * One process-wide load of the country table.
 *
 * Countries are reference data — the same ~250 rows for every store, every
 * panel, every session — so the first successful fetch is reused for the
 * rest of the page. React Query's cache alone is not enough: it is dropped
 * when the last picker unmounts (`gcTime`) and wiped on logout
 * (`queryClient.clear()`), which is why a country field on every sheet was
 * hitting the API again.
 *
 * A failed load is not stored, so the next picker can retry.
 */
let countriesRequest: Promise<{ data: PanelCountry[] }> | null = null

/**
 * The country list, loaded at most once per page. Subsequent callers share
 * the same in-flight or resolved promise.
 *
 * @returns The panel's country payload (`{ data }`).
 */
export function loadCountries(): Promise<{ data: PanelCountry[] }> {
  if (!countriesRequest) {
    countriesRequest = (getApiClient().listCountries?.() ?? Promise.resolve({ data: [] })).catch(
      (error: unknown) => {
        countriesRequest = null
        throw error
      },
    )
  }

  return countriesRequest
}

/** Drops the stored country list so the next read hits the API. For tests. */
export function resetCountriesCache(): void {
  countriesRequest = null
}

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
    queryFn: loadCountries,
    staleTime: Number.POSITIVE_INFINITY,
    gcTime: Number.POSITIVE_INFINITY,
  })

  const countries: PanelCountry[] = data?.data ?? []

  return { countries, isLoading }
}
