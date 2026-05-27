import { useQuery } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { adminClient } from '@/client'

const RESULT_LIMIT = 5
const MIN_QUERY_LENGTH = 2
const DEBOUNCE_MS = 200
const GC_TIME_MS = 60_000
const STALE_TIME_MS = 30_000

/**
 * Three parallel `?q[search]=…&limit=5` queries — one per resource. Each model
 * defines a `search` Ransack scope that does multi-field LIKE matching, so we
 * pass a single `search` param and let the server decide what to match.
 *
 * The query is debounced so a fast typist doesn't fan out a wave of in-flight
 * requests; results are cached briefly so backspace feels instant but they
 * don't pile up across long sessions.
 */
export function useGlobalSearch(rawQuery: string) {
  const query = useDebouncedValue(rawQuery, DEBOUNCE_MS)
  const enabled = query.trim().length >= MIN_QUERY_LENGTH

  const products = useQuery({
    queryKey: ['cmdk', 'products', query],
    queryFn: () => adminClient.products.list({ search: query, limit: RESULT_LIMIT }),
    enabled,
    gcTime: GC_TIME_MS,
    staleTime: STALE_TIME_MS,
  })

  const orders = useQuery({
    queryKey: ['cmdk', 'orders', query],
    queryFn: () => adminClient.orders.list({ search: query, limit: RESULT_LIMIT }),
    enabled,
    gcTime: GC_TIME_MS,
    staleTime: STALE_TIME_MS,
  })

  const customers = useQuery({
    queryKey: ['cmdk', 'customers', query],
    queryFn: () => adminClient.customers.list({ search: query, limit: RESULT_LIMIT }),
    enabled,
    gcTime: GC_TIME_MS,
    staleTime: STALE_TIME_MS,
  })

  return {
    products: products.data?.data ?? [],
    orders: orders.data?.data ?? [],
    customers: customers.data?.data ?? [],
    isLoading: enabled && (products.isLoading || orders.isLoading || customers.isLoading),
    isEnabled: enabled,
  }
}

function useDebouncedValue<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value)

  useEffect(() => {
    const id = setTimeout(() => setDebounced(value), delayMs)
    return () => clearTimeout(id)
  }, [value, delayMs])

  return debounced
}
