import { STORE_QUERY_RESOURCE, withStoreScope } from '@spree/dashboard-core'
import { QueryClient } from '@tanstack/react-query'
import { describe, expect, it } from 'vitest'
import { marketUpdateInvalidations, marketWriteInvalidations } from './use-markets'

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
  // A store's supported currencies and locales are the union of its markets',
  // so a market write leaves the cached store payload stale. Without this,
  // pickers reading `useStore()` keep offering removed currencies/locales.
  it('invalidates the store payload so derived currencies and locales refresh', () => {
    expect(staleKeysAfter(marketWriteInvalidations)).toContain('store')
    expect(staleKeysAfter(marketUpdateInvalidations('market_1'))).toContain('store')
  })

  it('invalidates every market query', () => {
    const stale = staleKeysAfter(marketWriteInvalidations)

    expect(stale).toContain('marketList')
    expect(stale).toContain('market')
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
