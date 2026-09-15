import { useResourceMutation } from '@spree/dashboard-core'
import type { AccountUpdateParams, MeResponse } from '@spree/seller-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { sellerClient } from '../api-client'

/**
 * The signed-in person's own account.
 *
 * Keyed without the seller, unlike almost everything else in this panel: the
 * account is the same record whichever seller they are acting for, so scoping
 * it per seller would refetch it on every switch and cache the same answer
 * several times over.
 *
 * @param enabled Defer the request until it is needed. The dialog is mounted
 *   on every page of the panel but only fetches once it opens.
 */
export function useAccount(enabled = true) {
  return useQuery({
    queryKey: ACCOUNT_KEY,
    queryFn: () => sellerClient().me.get(),
    enabled,
  })
}

export function useUpdateAccount() {
  const queryClient = useQueryClient()

  return useResourceMutation<MeResponse, Error, AccountUpdateParams>({
    mutationFn: (params) => sellerClient().me.update(params),
    // The person is also a row on the team page, so their own name and photo
    // there go stale on a self-edit unless that list is refetched. The hook
    // injects the seller at position 1, which is what the team page keys on.
    invalidate: [['seller', 'team']],
    successMessage: false, // the dialog toasts success itself
    errorMessage: false, // the dialog maps 422s inline via mapSpreeErrorsToForm
    // Write the response into the cache rather than leaning on invalidation
    // alone: the query is disabled while the dialog is closed, and an
    // invalidated query with no enabled observer goes stale without
    // refetching — so reopening would render the pre-save account, flashing
    // back a photo that was just removed.
    onSuccess: (updated) => queryClient.setQueryData(ACCOUNT_KEY, updated),
  })
}

const ACCOUNT_KEY = ['seller-account'] as const
