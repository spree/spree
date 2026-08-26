import type { Product, ProductCreateParams, ProductUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  STORE_QUERY_RESOURCE,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

export function useProduct(id: string) {
  return useQuery({
    queryKey: useResourceKey('products', id),
    queryFn: () =>
      adminClient.products.get(id, {
        expand: [
          'default_variant',
          'default_variant.prices',
          'default_variant.stock_levels',
          'default_variant.stock_levels.stock_location',
          'variants',
          'variants.prices',
          'variants.stock_levels',
          'variants.stock_levels.stock_location',
          'option_types',
          'categories',
          'collections',
          'tax_category',
          'product_publications',
          'channels',
          'custom_fields',
          // The seller card shows their standing alongside the name: a product
          // from a suspended seller is not on sale whatever its own status
          // says. One record on a detail page, so the expand is cheap here in
          // a way it would not be on the list.
          'seller',
          // Who decided this listing's fate and what they told the seller.
          'submission',
        ],
      }),
    enabled: !!id,
  })
}

export function useCreateProduct() {
  return useResourceMutation<Product, Error, ProductCreateParams>({
    mutationFn: (params) => adminClient.products.create(params),
    // STORE_QUERY_RESOURCE refreshes the setup-task state (Getting Started + nav badge).
    invalidate: [['products'], [STORE_QUERY_RESOURCE]],
    successMessage: false,
    errorMessage: false,
  })
}

export function useUpdateProduct() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<Product, Error, { id: string } & ProductUpdateParams>({
    mutationFn: ({ id, ...params }) => adminClient.products.update(id, params),
    invalidate: [['products']],
    successMessage: false,
    errorMessage: false,
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: buildKey('products', variables.id) })
    },
  })
}

/**
 * Closing a review a seller opened. Both refresh the product itself as well
 * as the list, since the status they write is what the list shows.
 */
export function useApproveProduct() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<Product, Error, string>({
    mutationFn: (id) => adminClient.products.approve(id),
    invalidate: [['products']],
    successMessage: false,
    errorMessage: false,
    onSuccess: (_data, id) => {
      queryClient.invalidateQueries({ queryKey: buildKey('products', id) })
    },
  })
}

export function useRejectProduct() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<Product, Error, { id: string; reason?: string }>({
    mutationFn: ({ id, reason }) => adminClient.products.reject(id, { reason }),
    invalidate: [['products']],
    successMessage: false,
    errorMessage: false,
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: buildKey('products', variables.id) })
    },
  })
}

export function useDeleteProduct() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.products.delete(id),
    invalidate: [['products'], [STORE_QUERY_RESOURCE]],
    successMessage: false,
    errorMessage: false,
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('products', id) })
    },
  })
}
