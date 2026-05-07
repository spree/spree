import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useProduct(id: string) {
  return useQuery({
    queryKey: ['products', id],
    queryFn: () =>
      adminClient.products.get(id, {
        expand: [
          'default_variant',
          'default_variant.prices',
          'variants',
          'variants.prices',
          'option_types',
          'categories',
          'tax_category',
        ],
      }),
    enabled: !!id,
  })
}

export function useUpdateProduct() {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, ...params }: { id: string } & Record<string, unknown>) =>
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
