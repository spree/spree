import type { ProductCreateParams, ProductUpdateParams } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

export function useProduct(id: string) {
  return useQuery({
    queryKey: ['products', id],
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
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: ProductCreateParams) => adminClient.products.create(params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products'] })
    },
  })
}

export function useUpdateProduct() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, ...params }: { id: string } & ProductUpdateParams) =>
      adminClient.products.update(id, params),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['products', variables.id] })
      queryClient.invalidateQueries({ queryKey: ['products'] })
    },
  })
}

export function useDeleteProduct() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) => adminClient.products.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products'] })
    },
  })
}
