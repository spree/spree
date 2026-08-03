import type { DeliveryZone, DeliveryZoneParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useDeliveryZones({
  page = 1,
  limit = 100,
}: {
  page?: number
  limit?: number
} = {}) {
  return useQuery({
    queryKey: useResourceKey('delivery-zones', { page, limit }),
    queryFn: () => adminClient.deliveryZones.list({ page, limit }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useDeliveryZone(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('delivery-zones', id ?? 'noop'),
    queryFn: () => adminClient.deliveryZones.get(id as string),
    enabled: !!id,
  })
}

export function useCreateDeliveryZone() {
  return useResourceMutation<DeliveryZone, Error, DeliveryZoneParams>({
    mutationFn: (params) => adminClient.deliveryZones.create(params),
    invalidate: [['delivery-zones']],
    successMessage: i18n.t('admin.delivery_zones.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateDeliveryZone(id: string) {
  return useResourceMutation<DeliveryZone, Error, DeliveryZoneParams>({
    mutationFn: (params) => adminClient.deliveryZones.update(id, params),
    invalidate: [['delivery-zones'], ['delivery-zones', id]],
    successMessage: i18n.t('admin.delivery_zones.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteDeliveryZone() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.deliveryZones.delete(id),
    invalidate: [['delivery-zones']],
    successMessage: i18n.t('admin.delivery_zones.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('delivery-zones', id) })
    },
  })
}
