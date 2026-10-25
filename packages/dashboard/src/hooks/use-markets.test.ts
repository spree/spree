import { STORE_QUERY_RESOURCE, withStoreScope } from '@spree/dashboard-core'
import { QueryClient } from '@tanstack/react-query'
import { describe, expect, it } from 'vitest'
import {
  marketAutocompleteProps,
  marketUpdateInvalidations,
  marketWriteInvalidations,
} from './use-markets'

const STORE_ID = 'store_abc123'

/**
 * Replays what `useResourceMutation` does on success — scope each logical key
 * to the store, then invalidate — and reports which of the seeded queries went
 * stale. Driving a real QueryClient means the assertions go through TanStack's
 * own prefix matching rather than a hand-rolled key comparison.
 */
function staleKeysAfter(invalidate: ReturnType<typeof marketUpdateInvalidations>): string[] {
  const queryClient = new QueryClient()

  const seeded: Record<string, unknown[]> = {
    store: [STORE_QUERY_RESOURCE, STORE_ID],
    marketList: ['markets', STORE_ID, 'all'],
    market: ['markets', STORE_ID, 'market_1'],
    otherMarket: ['markets', STORE_ID, 'market_2'],
    unrelated: ['products', STORE_ID],
  }

  for (const key of Object.values(seeded)) {
    queryClient.setQueryData(key, {})
  }

  for (const key of invalidate) {
    queryClient.invalidateQueries({ queryKey: withStoreScope(key, STORE_ID) })
  }

  return Object.entries(seeded)
    .filter(([, key]) => queryClient.getQueryState(key)?.isInvalidated)
    .map(([name]) => name)
}

describe('market write invalidations', () => {
  // The store payload still carries fields the server derives from markets.
  it('invalidates the store payload', () => {
    expect(staleKeysAfter(marketWriteInvalidations)).toContain('store')
    expect(staleKeysAfter(marketUpdateInvalidations('market_1'))).toContain('store')
  })

  // `marketList` is the shared list `useStore()` reads currencies and
  // languages from, so pickers drop a removed one at once.
  it('invalidates every market query', () => {
    const stale = staleKeysAfter(marketWriteInvalidations)

    expect(stale).toContain('marketList')
    expect(stale).toContain('market')
  })

  // The store shell and the market list filter read the same cached list,
  // so these writes refresh both without waiting for its hour to pass.
  it('names the filter cache after markets so these writes reach it', () => {
    expect(marketAutocompleteProps().queryKey).toBe('markets')
  })

  it('leaves unrelated resources cached', () => {
    expect(staleKeysAfter(marketWriteInvalidations)).not.toContain('unrelated')
    expect(staleKeysAfter(marketUpdateInvalidations('market_1'))).not.toContain('unrelated')
  })

  it('scopes invalidation to the current store', () => {
    const queryClient = new QueryClient()
    const otherStoreKey = [STORE_QUERY_RESOURCE, 'store_other']
    queryClient.setQueryData(otherStoreKey, {})

    for (const key of marketWriteInvalidations) {
      queryClient.invalidateQueries({ queryKey: withStoreScope(key, STORE_ID) })
    }

    expect(queryClient.getQueryState(otherStoreKey)?.isInvalidated).toBe(false)
  })
})
