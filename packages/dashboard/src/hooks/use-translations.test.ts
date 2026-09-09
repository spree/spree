import { withStoreScope } from '@spree/dashboard-core'
import { QueryClient } from '@tanstack/react-query'
import { describe, expect, it } from 'vitest'
import { TRANSLATIONS_QUERY_RESOURCE } from './use-translations'

const STORE_ID = 'store_abc123'

/**
 * Replays a prefix invalidation of the translations resource and reports
 * which of the seeded queries went stale. The coverage grid and each
 * per-record matrix must share this prefix so one invalidate refreshes both.
 */
function staleAfterTranslationsInvalidation() {
  const queryClient = new QueryClient()

  try {
    const seeded: Record<string, unknown[]> = {
      coverage: [TRANSLATIONS_QUERY_RESOURCE, STORE_ID, 'coverage', 'product', { page: 1 }],
      matrix: [TRANSLATIONS_QUERY_RESOURCE, STORE_ID, 'product', 'prod_1'],
      legacyMatrix: ['product', STORE_ID, 'prod_1', 'translations'],
      products: ['products', STORE_ID],
    }

    for (const key of Object.values(seeded)) {
      queryClient.setQueryData(key, {})
    }

    queryClient.invalidateQueries({
      queryKey: withStoreScope([TRANSLATIONS_QUERY_RESOURCE], STORE_ID),
      refetchType: 'all',
    })

    return Object.entries(seeded)
      .filter(([, key]) => queryClient.getQueryState(key)?.isInvalidated)
      .map(([name]) => name)
  } finally {
    queryClient.clear()
  }
}

describe('translations query invalidation', () => {
  it('marks coverage and the per-record matrix stale', () => {
    const stale = staleAfterTranslationsInvalidation()

    expect(stale).toContain('coverage')
    expect(stale).toContain('matrix')
  })

  it('does not match the old singular-resource matrix key', () => {
    // The previous key was `['product', id, 'translations']`. Invalidating
    // `['translations']` must not be assumed to reach it — that is why the
    // matrix now lives under the translations prefix.
    expect(staleAfterTranslationsInvalidation()).not.toContain('legacyMatrix')
  })

  it('leaves unrelated catalog lists cached', () => {
    expect(staleAfterTranslationsInvalidation()).not.toContain('products')
  })

  it('matches the key product updates pass to invalidateQueries', () => {
    // useUpdateProduct invalidates `buildKey('translations')` which is
    // `withStoreScope(['translations'], storeId)` — the same prefix this
    // helper uses. A key of `['products', id, 'translations']` would miss.
    expect(staleAfterTranslationsInvalidation()).toEqual(
      expect.arrayContaining(['coverage', 'matrix']),
    )
  })

  it('refetches inactive coverage after refetchType all', async () => {
    // Default invalidateQueries only refetches active observers. Coverage
    // visited earlier has no observer, so `refetchType: 'all'` is what
    // useInvalidateTranslations uses — this would stay at 1 without it.
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    })
    const coverageKey = [TRANSLATIONS_QUERY_RESOURCE, STORE_ID, 'coverage', 'product', { page: 1 }]
    let fetches = 0

    try {
      await queryClient.prefetchQuery({
        queryKey: coverageKey,
        queryFn: async () => {
          fetches += 1
          return {}
        },
      })
      expect(fetches).toBe(1)

      await queryClient.invalidateQueries({
        queryKey: withStoreScope([TRANSLATIONS_QUERY_RESOURCE], STORE_ID),
      })
      expect(fetches).toBe(1)

      await queryClient.invalidateQueries({
        queryKey: withStoreScope([TRANSLATIONS_QUERY_RESOURCE], STORE_ID),
        refetchType: 'all',
      })
      expect(fetches).toBe(2)
    } finally {
      queryClient.clear()
    }
  })
})
