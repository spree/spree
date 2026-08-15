import type { MeResponse, MeUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

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
  const queryClient = useQueryClient()
  const profileKey = useResourceKey('profile')

  return useResourceMutation<MeResponse, Error, MeUpdateParams>({
    mutationFn: (params) => adminClient.me.update(params),
    // The signed-in admin is also a row on the staff page, so their own name
    // and avatar there go stale on a self-edit unless that list is refetched.
    invalidate: [['profile'], ['staff']],
    successMessage: false, // the dialog toasts success itself
    errorMessage: false, // the dialog maps 422s inline via mapSpreeErrorsToForm
    // Write the response into the cache instead of leaning on the invalidation
    // alone. The dialog disables the profile query while closed, and an
    // invalidated query with no enabled observer goes stale without refetching
    // — so a reopen would otherwise render the pre-save profile (flashing back
    // an avatar the admin just removed).
    onSuccess: (updated) => queryClient.setQueryData(profileKey, updated),
  })
}
