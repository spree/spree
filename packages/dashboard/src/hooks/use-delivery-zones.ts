import type { DeliveryZone, DeliveryZoneParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

/**
 * Every zone of one profile, members included — the profile page renders each
 * zone as its own card, so a page-one cap would hide zones from the merchant.
 */
export function useProfileDeliveryZones(deliveryProfileId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('delivery-zones', 'by-profile', deliveryProfileId ?? 'noop'),
    queryFn: async () => {
      const first = await adminClient.deliveryZones.list({
        page: 1,
        limit: 100,
        expand: ['members'],
        delivery_profile_id_eq: deliveryProfileId,
      })
      const rest = await Promise.all(
        Array.from({ length: (first.meta?.pages ?? 1) - 1 }, (_, index) =>
          adminClient.deliveryZones.list({
            page: index + 2,
            limit: 100,
            expand: ['members'],
            delivery_profile_id_eq: deliveryProfileId,
          }),
        ),
      )
      const zones = [...first.data, ...rest.flatMap((page) => page.data)]
      // The filter is a Ransack hint the server may not honour, so the
      // profile's own zones are selected here as well — a zone leaking in
      // from another profile would offer methods this profile cannot use.
      return zones.filter((zone) => zone.delivery_profile_id === deliveryProfileId)
    },
    enabled: !!deliveryProfileId,
  })
}

export function useDeliveryZone(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('delivery-zones', id ?? 'noop'),
    // Members are expand-gated: without this the edit form loads an empty
    // member list and saving would replace the real members with nothing.
    queryFn: () => adminClient.deliveryZones.get(id as string, { expand: ['members'] }),
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
