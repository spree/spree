import type { DeliveryOriginGroup, DeliveryOriginGroupParams } from '@spree/admin-sdk'
import { adminClient, useResourceMutation } from '@spree/dashboard-core'
import i18n from 'i18next'

export function useCreateDeliveryOriginGroup(deliveryProfileId: string) {
  return useResourceMutation<DeliveryOriginGroup, Error, DeliveryOriginGroupParams>({
    mutationFn: (params) =>
      adminClient.deliveryProfiles.originGroups.create(deliveryProfileId, params),
    invalidate: [
      ['delivery-origin-groups', deliveryProfileId],
      ['delivery-profiles'],
      ['delivery-profiles', deliveryProfileId],
    ],
    successMessage: i18n.t('admin.delivery_origin_groups.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateDeliveryOriginGroup(deliveryProfileId: string, id: string) {
  return useResourceMutation<DeliveryOriginGroup, Error, DeliveryOriginGroupParams>({
    mutationFn: (params) =>
      adminClient.deliveryProfiles.originGroups.update(deliveryProfileId, id, params),
    invalidate: [
      ['delivery-origin-groups', deliveryProfileId],
      ['delivery-profiles'],
      ['delivery-profiles', deliveryProfileId],
    ],
    successMessage: i18n.t('admin.delivery_origin_groups.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteDeliveryOriginGroup(deliveryProfileId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.deliveryProfiles.originGroups.delete(deliveryProfileId, id),
    invalidate: [
      ['delivery-origin-groups', deliveryProfileId],
      ['delivery-profiles'],
      ['delivery-profiles', deliveryProfileId],
      // Deleting a group is refused while it still holds zones or methods, so
      // a success means both lists are unchanged — but the profile's zones are
      // re-read anyway, since the merchant may have moved them first.
      ['delivery-zones'],
      ['delivery-methods'],
    ],
    successMessage: i18n.t('admin.delivery_origin_groups.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}
