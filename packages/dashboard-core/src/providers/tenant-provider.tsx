import { createContext, type ReactNode, useContext, useMemo } from 'react'
import { useOptionalStore } from './store-provider'

/**
 * Which tenant the signed-in principal is currently acting as — a store in the
 * operator's dashboard, a seller in the marketplace panel.
 *
 * Query keys have to be scoped to it (a cached list must never survive a
 * switch and be shown under the next tenant), and shared pages cannot reach
 * for `useStore` to get it: a seller panel mounts no `StoreProvider`, so that
 * throws. `useTenantId` reads this provider, falls back to the store when only
 * a `StoreProvider` is mounted, and answers `'default'` when neither is —
 * which keeps the operator's dashboard working with no change at all.
 */
const TenantContext = createContext<string | null>(null)

export function TenantProvider({ id, children }: { id: string; children: ReactNode }) {
  const value = useMemo(() => id, [id])

  return <TenantContext.Provider value={value}>{children}</TenantContext.Provider>
}

/**
 * The current tenant's id, for query-key scoping.
 *
 * @returns the tenant id, or `'default'` when no provider is mounted
 */
export function useTenantId(): string {
  const explicit = useContext(TenantContext)
  const store = useOptionalStore()

  return explicit ?? store?.storeId ?? 'default'
}
