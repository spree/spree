import type { Product, ProductCreateParams, ProductUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
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
          'default_variant.stock_items',
          'default_variant.stock_items.stock_location',
          'variants',
          'variants.prices',
          'variants.stock_items',
          'variants.stock_items.stock_location',
          'option_types',
          'categories',
          'tax_category',
          'product_publications',
          'channels',
        ],
      }),
    enabled: !!id,
  })
}

export function useCreateProduct() {
  return useResourceMutation<Product, Error, ProductCreateParams>({
    mutationFn: (params) => adminClient.products.create(params),
    invalidate: [['products']],
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

export function useDeleteProduct() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.products.delete(id),
    invalidate: [['products']],
    successMessage: false,
    errorMessage: false,
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('products', id) })
    },
  })
}
