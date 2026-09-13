import type { StoreCredit } from '@spree/admin-sdk'
import { adminClient, useResourceKey } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function listStoreCredits(params: Parameters<typeof adminClient.storeCredits.list>[0]) {
  return adminClient.storeCredits.list(params)
}

export function useStoreCredit(id: string | undefined, expand?: string[]) {
  const base = useResourceKey('store-credits', id ?? 'noop')
  return useQuery<StoreCredit>({
    queryKey: expand?.length ? [...base, { expand }] : base,
    queryFn: () => adminClient.storeCredits.get(id as string, { expand }),
    enabled: !!id,
  })
}

/**
 * The credit's ledger — every movement of its balance, newest first.
 *
 * Paged rather than capped: a credit authorized and voided across many
 * checkouts accumulates entries without limit, and this panel is the audit
 * view, so silently dropping the older half is the one thing it must not do.
 */
export function useStoreCreditEvents(storeCreditId: string | undefined, page = 1) {
  const queryKey = useResourceKey('store-credits', storeCreditId ?? 'noop', 'events', page)
  return useQuery({
    queryKey,
    queryFn: () => adminClient.storeCredits.events.list(storeCreditId as string, { page }),
    enabled: !!storeCreditId,
    placeholderData: (previous) => previous,
  })
}
