import { useQuery } from '@tanstack/react-query'
import { adminClient } from '@/client'

// Lists media linked to a variant. Mutations go through useUpdateProductMedia
// with `variant_ids` — there's no variant-scoped mutation endpoint.
export function useVariantMedia(productId: string, variantId: string) {
  return useQuery({
    queryKey: ['products', productId, 'variants', variantId, 'media'],
    queryFn: () => adminClient.products.variants.media.list(productId, variantId),
    enabled: !!productId && !!variantId,
  })
}
