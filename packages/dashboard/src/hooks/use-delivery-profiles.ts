import type { DeliveryProfile, DeliveryProfileParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useDeliveryProfiles({
  page = 1,
  limit = 100,
}: {
  page?: number
  limit?: number
} = {}) {
  return useQuery({
    queryKey: useResourceKey('delivery-profiles', { page, limit }),
    queryFn: () => adminClient.deliveryProfiles.list({ page, limit }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useDeliveryProfile(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('delivery-profiles', id ?? 'noop'),
    queryFn: () => adminClient.deliveryProfiles.get(id as string),
    enabled: !!id,
  })
}

/** Registered profile kinds — shipping, digital, plus any an extension adds. */
export function useDeliveryProfileKinds() {
  return useQuery({
    queryKey: useResourceKey('delivery-profile-kinds'),
    queryFn: () => adminClient.deliveryProfiles.kinds(),
    staleTime: 1000 * 60 * 30,
  })
}

export function useCreateDeliveryProfile() {
  return useResourceMutation<DeliveryProfile, Error, DeliveryProfileParams & { name: string }>({
    mutationFn: (params) => adminClient.deliveryProfiles.create(params),
    invalidate: [['delivery-profiles']],
    successMessage: i18n.t('admin.delivery_profiles.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateDeliveryProfile(id: string) {
  return useResourceMutation<DeliveryProfile, Error, DeliveryProfileParams>({
    mutationFn: (params) => adminClient.deliveryProfiles.update(id, params),
    invalidate: [['delivery-profiles'], ['delivery-profiles', id]],
    successMessage: i18n.t('admin.delivery_profiles.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteDeliveryProfile() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.deliveryProfiles.delete(id),
    invalidate: [['delivery-profiles']],
    successMessage: i18n.t('admin.delivery_profiles.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('delivery-profiles', id) })
    },
  })
}
