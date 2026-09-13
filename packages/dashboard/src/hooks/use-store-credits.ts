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

/** The credit's ledger — every movement of its balance, newest first. */
export function useStoreCreditEvents(storeCreditId: string | undefined) {
  const queryKey = useResourceKey('store-credits', storeCreditId ?? 'noop', 'events')
  return useQuery({
    queryKey,
    queryFn: () => adminClient.storeCredits.events.list(storeCreditId as string, { limit: 100 }),
    enabled: !!storeCreditId,
  })
}
