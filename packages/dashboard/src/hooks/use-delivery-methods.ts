import type { DeliveryMethod, DeliveryMethodParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useDeliveryMethod(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('delivery-methods', id ?? 'noop'),
    queryFn: () => adminClient.deliveryMethods.get(id as string),
    enabled: !!id,
  })
}

export function useDeliveryCalculators() {
  return useQuery({
    queryKey: useResourceKey('delivery-methods', 'calculators'),
    queryFn: () => adminClient.deliveryMethods.calculators(),
    staleTime: 1000 * 60 * 30,
  })
}

export function useCreateDeliveryMethod() {
  return useResourceMutation<DeliveryMethod, Error, DeliveryMethodParams>({
    mutationFn: (params) => adminClient.deliveryMethods.create(params),
    invalidate: [['delivery-methods']],
    successMessage: i18n.t('admin.delivery_methods.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateDeliveryMethod(id: string) {
  return useResourceMutation<DeliveryMethod, Error, DeliveryMethodParams>({
    mutationFn: (params) => adminClient.deliveryMethods.update(id, params),
    invalidate: [['delivery-methods'], ['delivery-methods', id]],
    successMessage: i18n.t('admin.delivery_methods.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteDeliveryMethod() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.deliveryMethods.delete(id),
    invalidate: [['delivery-methods']],
    successMessage: i18n.t('admin.delivery_methods.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('delivery-methods', id) })
    },
  })
}
