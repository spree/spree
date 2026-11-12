import { toastManager } from '@spree/dashboard-ui'
import type { ProfileUpdateParams } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useParams } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

export function useProfile() {
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })

  return useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
  })
}

/** Saves part of the seller's own record, wherever in the panel it is edited. */
export function useUpdateProfile() {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: ProfileUpdateParams) => sellerClient().profile.update(params),
    onSuccess: (updated) => {
      queryClient.setQueryData(['seller', sellerId, 'profile'], updated)
      // Onboarding requirements read the profile, so the checklist re-evaluates.
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'onboarding'] })
      toastManager.add({ type: 'success', title: t('profile.saved') })
    },
    onError: (err) =>
      toastManager.add({
        type: 'error',
        title: err instanceof Error && err.message ? err.message : t('common.error'),
      }),
  })
}
