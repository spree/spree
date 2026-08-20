import type { QueryKey } from '@tanstack/react-query'
import { useCallback } from 'react'
import { useTenantId } from '../providers/tenant-provider'

/**
 * Canonical TanStack query-key shape for every dashboard resource:
 *
 *     [resource, tenantId, ...rest]
 *
 * Use `useResourceKey` (the hook) from inside React components to build
 * tenant-scoped keys — it reads the id from `<TenantProvider>` (falling back
 * to `<StoreProvider>`) so callers never spell it themselves:
 *
 *     useQuery({ queryKey: useResourceKey('channels', id), ... })
 *
 * The bare `resourceKey()` helper is the same builder without the tenant id
 * dependency — keep it for non-hook contexts (tests, build-time defaults).
 *
 * Lists: `useResourceKey('channels')`
 * Singletons: `useResourceKey('channels', id)`
 * Nested: `useResourceKey('products', productId, 'variants')`
 *
 * For invalidation inside `useResourceMutation`, the tenant id is auto-injected
 * — pass the logical key without it:
 *
 *     invalidate: [['channels'], ['channels', id]]
 */
export function resourceKey(resource: string, ...rest: ReadonlyArray<unknown>): QueryKey {
  return [resource, ...rest]
}

/**
 * Hook variant of `resourceKey` that auto-injects the current tenant id from
 * `<TenantProvider>`. The default way to build query keys in dashboard hooks.
 */
export function useResourceKey(resource: string, ...rest: ReadonlyArray<unknown>): QueryKey {
  const tenantId = useTenantId()
  return [resource, tenantId, ...rest]
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
  const tenantId = useTenantId()
  return useCallback(
    (resource: string, ...rest: ReadonlyArray<unknown>): QueryKey => [resource, tenantId, ...rest],
    [tenantId],
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
