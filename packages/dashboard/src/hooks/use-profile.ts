import type { MeResponse, MeUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * @param enabled Defer the request until it's needed. The edit-profile dialog
 *   is mounted on every store page but only fetches once it opens.
 */
export function useProfile(enabled = true) {
  return useQuery({
    queryKey: useResourceKey('profile'),
    queryFn: () => adminClient.me.get(),
    enabled,
  })
}

export function useUpdateProfile() {
  return useResourceMutation<MeResponse, Error, MeUpdateParams>({
    mutationFn: (params) => adminClient.me.update(params),
    invalidate: [['profile']],
    successMessage: false, // the page toasts success itself
    errorMessage: false, // the page maps 422s inline via mapSpreeErrorsToForm
  })
}
