import type { MeResponse, MeUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useProfile() {
  return useQuery({
    queryKey: useResourceKey('profile'),
    queryFn: () => adminClient.me.get(),
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
