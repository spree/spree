import type { QueryKey } from '@tanstack/react-query'
import { useCallback } from 'react'
import { useStore } from '../providers/store-provider'

/**
 * Canonical TanStack query-key shape for every dashboard resource:
 *
 *     [resource, storeId, ...rest]
 *
 * Use `useResourceKey` (the hook) from inside React components to build
 * store-scoped keys — it reads `storeId` from `<StoreProvider>` so callers
 * never spell it themselves:
 *
 *     useQuery({ queryKey: useResourceKey('channels', id), ... })
 *
 * The bare `resourceKey()` helper is the same builder without the storeId
 * dependency — keep it for non-hook contexts (tests, build-time defaults).
 *
 * Lists: `useResourceKey('channels')`
 * Singletons: `useResourceKey('channels', id)`
 * Nested: `useResourceKey('products', productId, 'variants')`
 *
 * For invalidation inside `useResourceMutation`, the storeId is auto-injected
 * — pass the logical key without it:
 *
 *     invalidate: [['channels'], ['channels', id]]
 */
export function resourceKey(resource: string, ...rest: ReadonlyArray<unknown>): QueryKey {
  return [resource, ...rest]
}

/**
 * Hook variant of `resourceKey` that auto-injects the current `storeId` from
 * `<StoreProvider>`. The default way to build query keys in dashboard hooks.
 */
export function useResourceKey(resource: string, ...rest: ReadonlyArray<unknown>): QueryKey {
  const { storeId } = useStore()
  return [resource, storeId, ...rest]
}

/**
 * Returns a stable closure that builds store-scoped query keys. Use this when
 * the key parts (typically an id) are only known later — e.g. inside a
 * mutation's `onSuccess` where `variables.id` is per-call.
 *
 *     const buildKey = useResourceKeyBuilder()
 *     return useResourceMutation({
 *       onSuccess: (_data, id) =>
 *         queryClient.removeQueries({ queryKey: buildKey('channels', id) }),
 *     })
 */
export function useResourceKeyBuilder() {
  const { storeId } = useStore()
  return useCallback(
    (resource: string, ...rest: ReadonlyArray<unknown>): QueryKey => [resource, storeId, ...rest],
    [storeId],
  )
}

/**
 * Inject `storeId` at position 1 of a query key, leaving the resource name at
 * position 0 and any further scope after it. Idempotent — if the storeId is
 * already at position 1, returns the input unchanged.
 */
export function withStoreScope(key: QueryKey, storeId: string): QueryKey {
  if (!Array.isArray(key) || key.length === 0) return key
  if (key[1] === storeId) return key
  return [key[0], storeId, ...key.slice(1)]
}
