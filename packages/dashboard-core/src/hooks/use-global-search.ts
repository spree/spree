import { useQueries } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { useAuth } from '../hooks/use-auth'
import { type SearchEntry, useSearchEntries } from '../lib/search-registry'
import { usePermissions } from '../providers/permission-provider'
import { useStore } from '../providers/store-provider'

const RESULT_LIMIT = 5
const MIN_QUERY_LENGTH = 2
const DEBOUNCE_MS = 200
const GC_TIME_MS = 60_000
const STALE_TIME_MS = 30_000

export interface SearchGroup {
  entry: SearchEntry
  items: unknown[]
}

/**
 * One parallel `?q[search]=…&limit=5` query per registered, permitted search
 * entry — products, orders, customers, promotions, and anything a plugin adds.
 * Each resource defines a `search` Ransack scope server-side that does
 * multi-field LIKE matching, so we pass a single `search` param and let the
 * server decide what to match.
 *
 * The query is debounced so a fast typist doesn't fan out a wave of in-flight
 * requests; results are cached briefly (and scoped by user + store) so backspace
 * feels instant but they don't pile up or leak across users or stores.
 */
export function useGlobalSearch(rawQuery: string) {
  // Trim once: the cache key and the server query must match what `enabled`
  // gates on, or " hello" and "hello" fan out as separate cache entries and the
  // stray space leaks into the `cont` predicate (`LIKE %hello %`), missing rows.
  const query = useDebouncedValue(rawQuery, DEBOUNCE_MS).trim()
  const enabled = query.length >= MIN_QUERY_LENGTH
  const entries = useSearchEntries()
  const { permissions, isLoading: permissionsLoading } = usePermissions()
  const { storeId } = useStore()
  const { user } = useAuth()

  const permitted = entries.filter((e) => !e.subject || permissions.can('read', e.subject))

  const results = useQueries({
    queries: permitted.map((entry) => ({
      // Scope by user so a logout→login on the same store can't serve the
      // previous user's cached results from React Query.
      queryKey: ['cmdk', user?.id, storeId, entry.key, query],
      queryFn: () => entry.fetch(query, RESULT_LIMIT),
      enabled,
      gcTime: GC_TIME_MS,
      staleTime: STALE_TIME_MS,
    })),
  })

  const groups: SearchGroup[] = permitted
    .map((entry, i) => ({ entry, items: results[i]?.data ?? [] }))
    .filter((g) => g.items.length > 0)

  return {
    groups,
    // Treat the permission fetch as loading: until rules land, every gated
    // entry is filtered out and no queries run, so without this the palette
    // would flash "no results" before search has effectively started.
    isLoading: enabled && (permissionsLoading || results.some((r) => r.isLoading)),
    isEnabled: enabled,
    hasResults: groups.length > 0,
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
