import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

const RESULT_LIMIT = 5
const MIN_QUERY_LENGTH = 2

/**
 * Three parallel `?q[search]=…&limit=5` queries — one per resource. Each model
 * defines a `search` Ransack scope that does multi-field LIKE matching, so we
 * pass a single `search` param and let the server decide what to match.
 *
 * Below `MIN_QUERY_LENGTH` chars all queries are disabled — typing one letter
 * would generate a wave of 3 requests per keystroke for very low-signal data.
 */
export function useGlobalSearch(query: string) {
  const enabled = query.trim().length >= MIN_QUERY_LENGTH

  const products = useQuery({
    queryKey: ['cmdk', 'products', query],
    queryFn: () => adminClient.products.list({ search: query, limit: RESULT_LIMIT }),
    enabled,
  })

  const orders = useQuery({
    queryKey: ['cmdk', 'orders', query],
    queryFn: () => adminClient.orders.list({ search: query, limit: RESULT_LIMIT }),
    enabled,
  })

  const customers = useQuery({
    queryKey: ['cmdk', 'customers', query],
    queryFn: () => adminClient.customers.list({ search: query, limit: RESULT_LIMIT }),
    enabled,
  })

  return {
    products: products.data?.data ?? [],
    orders: orders.data?.data ?? [],
    customers: customers.data?.data ?? [],
    isLoading: enabled && (products.isLoading || orders.isLoading || customers.isLoading),
    isEnabled: enabled,
  }
}
