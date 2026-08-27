import { adminClient, i18n, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

type DigitalAssetCreateParams = Parameters<typeof adminClient.products.digitalAssets.create>[1]
type DigitalAssetUpdateParams = Parameters<typeof adminClient.products.digitalAssets.update>[2]

// The logical invalidation key (tenant id auto-injected by useResourceMutation).
const digitalAssetsKey = (productId: string) => ['products', productId, 'digital-assets']

export function useDigitalAssets(productId: string, page = 1, enabled = true) {
  return useQuery({
    queryKey: useResourceKey('products', productId, 'digital-assets', page),
    queryFn: () => adminClient.products.digitalAssets.list(productId, { page, per_page: 25 }),
    enabled: enabled && Boolean(productId),
  })
}

// The selectable sources for a new asset. Almost always just the File default,
// so a host with no extra provider gets a one-entry list and the card keeps its
// plain "Add file" button.
export function useDigitalAssetProviders(productId: string, enabled = true) {
  return useQuery({
    queryKey: useResourceKey('products', productId, 'digital-asset-providers'),
    queryFn: () => adminClient.products.digitalAssets.providers(productId),
    enabled: enabled && Boolean(productId),
    staleTime: Number.POSITIVE_INFINITY, // the registry doesn't change at runtime
  })
}

export function useCreateDigitalAsset(productId: string) {
  return useResourceMutation({
    mutationFn: (params: DigitalAssetCreateParams) =>
      adminClient.products.digitalAssets.create(productId, params),
    invalidate: [digitalAssetsKey(productId)],
    successMessage: i18n.t('admin.messages.digital_asset_saved'),
  })
}

export function useUpdateDigitalAsset(productId: string) {
  return useResourceMutation({
    mutationFn: ({ id, ...params }: DigitalAssetUpdateParams & { id: string }) =>
      adminClient.products.digitalAssets.update(productId, id, params),
    invalidate: [digitalAssetsKey(productId)],
    successMessage: i18n.t('admin.messages.digital_asset_saved'),
  })
}

export function useDeleteDigitalAsset(productId: string) {
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.products.digitalAssets.delete(productId, id),
    invalidate: [digitalAssetsKey(productId)],
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
  return useResourceMutation({
    mutationFn: (id: string) => adminClient.digitalLinks.reset(id),
    invalidate: [['orders', orderId]],
    successMessage: i18n.t('admin.messages.digital_link_reset'),
  })
}
