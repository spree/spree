import type { Country, State } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useSortByCountryName } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import { useMemo } from 'react'

/**
 * Every country the store actually sells into, unioned across its markets and
 * sorted by the name the admin reads. Pickers that ask "where can we deliver?" scope to this rather
 * than the ~250-row country table, since a country outside every market can
 * never appear on an order.
 */
export function useMarketCountries() {
  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('markets', 'countries'),
    queryFn: () => adminClient.markets.list({ limit: 100, expand: ['countries'] }),
    staleTime: 1000 * 60 * 30,
  })

  const sortByName = useSortByCountryName()
  const countries = useMemo(() => {
    const byIso = new Map<string, Country>()
    for (const market of data?.data ?? []) {
      for (const country of market.countries ?? []) {
        if (!byIso.has(country.iso)) byIso.set(country.iso, country)
      }
    }
    return sortByName([...byIso.values()], (country) => country.iso)
  }, [data, sortByName])

  return { countries, isLoading }
}

/**
 * States of one country, fetched only once the caller asks for them — a picker
 * listing dozens of countries would otherwise fire a request per row.
 */
export function useCountryStates(iso: string | undefined, enabled = true) {
  const { data, isLoading } = useQuery({
    queryKey: useResourceKey('countries', iso ?? 'noop', 'states'),
    queryFn: () => adminClient.countries.get(iso as string, { expand: ['states'] }),
    enabled: !!iso && enabled,
    staleTime: 1000 * 60 * 60,
  })

  const states: State[] = [...(data?.states ?? [])].sort((left, right) =>
    left.name.localeCompare(right.name),
  )

  return { states, isLoading }
}
