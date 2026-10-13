import { PermissionProvider } from '@spree/dashboard-core'
import { type AnyRouter, useRouterState } from '@tanstack/react-router'
import type { ReactNode } from 'react'

/**
 * Loads the permissions of the store that is open. The provider sits above the
 * router, out of reach of the store route's `StoreProvider`, so the store id is
 * read from the router instead — the same id that route sends with every
 * request. Outside a store the id is undefined and permissions are kept apart.
 */
export function StorePermissionProvider({
  router,
  children,
}: {
  router: AnyRouter
  children: ReactNode
}) {
  const storeId = useRouterState({
    router,
    select: (state) => (state.matches.at(-1)?.params as { storeId?: string } | undefined)?.storeId,
  })

  return <PermissionProvider tenantId={storeId}>{children}</PermissionProvider>
}
