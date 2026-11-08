import { getApiClient, i18n, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import type { PanelDigitalAssetParams } from '../api-client'

// The logical invalidation key (tenant id auto-injected by useResourceMutation).
const digitalAssetsKey = (productId: string) => ['products', productId, 'digital-assets']

function digitalAssetsClient() {
  const client = getApiClient().digitalAssets
  if (!client) throw new Error('This panel cannot manage digital files.')
  return client
}

export function useDigitalAssets(productId: string, page = 1, enabled = true) {
  return useQuery({
    queryKey: useResourceKey('products', productId, 'digital-assets', page),
    queryFn: () => digitalAssetsClient().list(productId, { page, limit: 25 }),
    enabled: enabled && Boolean(productId) && Boolean(getApiClient().digitalAssets),
  })
}

// The selectable sources for a new asset. Almost always just the File default,
// so a host with no extra provider gets a one-entry list and the card keeps its
// plain "Add file" button.
export function useDigitalAssetProviders(productId: string, enabled = true) {
  const providers = getApiClient().digitalAssets?.providers
  return useQuery({
    // Not keyed by product: the registry is the same for all of them.
    queryKey: useResourceKey('digital-asset-providers'),
    queryFn: () => providers!(productId),
    enabled: enabled && Boolean(productId) && Boolean(providers),
    staleTime: Number.POSITIVE_INFINITY, // the registry doesn't change at runtime
  })
}

/**
 * `errorMessage: false` hands every failure to the caller — the card names
 * the file in its own toast, and two toasts for one refusal is noise.
 */
export function useCreateDigitalAsset(productId: string, options: { errorMessage?: false } = {}) {
  return useResourceMutation({
    mutationFn: (params: PanelDigitalAssetParams) =>
      digitalAssetsClient().create(productId, params),
    invalidate: [digitalAssetsKey(productId)],
    successMessage: i18n.t('admin.messages.digital_asset_saved'),
    ...options,
  })
}

export function useUpdateDigitalAsset(productId: string, options: { errorMessage?: false } = {}) {
  return useResourceMutation({
    mutationFn: ({ id, ...params }: PanelDigitalAssetParams & { id: string }) =>
      digitalAssetsClient().update(productId, id, params),
    invalidate: [digitalAssetsKey(productId)],
    successMessage: i18n.t('admin.messages.digital_asset_saved'),
    ...options,
  })
}

export function useDeleteDigitalAsset(productId: string) {
  return useResourceMutation({
    mutationFn: (id: string) => digitalAssetsClient().delete(productId, id),
    invalidate: [digitalAssetsKey(productId)],
    successMessage: i18n.t('admin.messages.digital_asset_removed'),
  })
}
