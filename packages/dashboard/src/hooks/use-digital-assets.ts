import { adminClient, i18n, useResourceMutation, useStore } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

type DigitalAssetCreateParams = Parameters<typeof adminClient.products.digitalAssets.create>[1]
type DigitalAssetUpdateParams = Parameters<typeof adminClient.products.digitalAssets.update>[2]

export function useDigitalAssets(productId: string, page = 1, enabled = true) {
  const { storeId } = useStore()

  return useQuery({
    queryKey: [storeId, 'products', productId, 'digital-assets', page],
    queryFn: () => adminClient.products.digitalAssets.list(productId, { page, per_page: 25 }),
    enabled: enabled && Boolean(productId),
  })
}

export function useCreateDigitalAsset(productId: string) {
  const { storeId } = useStore()

  return useResourceMutation({
    mutationFn: (params: DigitalAssetCreateParams) =>
      adminClient.products.digitalAssets.create(productId, params),
    invalidate: [[storeId, 'products', productId, 'digital-assets']],
    successMessage: i18n.t('admin.messages.digital_asset_saved'),
  })
}

export function useUpdateDigitalAsset(productId: string) {
  const { storeId } = useStore()

  return useResourceMutation({
    mutationFn: ({ id, ...params }: DigitalAssetUpdateParams & { id: string }) =>
      adminClient.products.digitalAssets.update(productId, id, params),
    invalidate: [[storeId, 'products', productId, 'digital-assets']],
    successMessage: i18n.t('admin.messages.digital_asset_saved'),
  })
}

export function useDeleteDigitalAsset(productId: string) {
  const { storeId } = useStore()

  return useResourceMutation({
    mutationFn: (id: string) => adminClient.products.digitalAssets.delete(productId, id),
    invalidate: [[storeId, 'products', productId, 'digital-assets']],
    successMessage: i18n.t('admin.messages.digital_asset_removed'),
  })
}

export function useResendDigitalLinks(orderId: string) {
  return useResourceMutation({
    mutationFn: () => adminClient.orders.resendDigitalLinks(orderId),
    successMessage: i18n.t('admin.messages.digital_links_email_sent'),
  })
}

export function useResetDigitalLink(orderId: string) {
  const { storeId } = useStore()

  return useResourceMutation({
    mutationFn: (id: string) => adminClient.digitalLinks.reset(id),
    invalidate: [[storeId, 'orders', orderId]],
    successMessage: i18n.t('admin.messages.digital_link_reset'),
  })
}
