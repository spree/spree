import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { spreeClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

export function useProduct(id: string) {
  const { token } = useAuth()

  return useQuery({
    queryKey: ['products', id],
    queryFn: () =>
      spreeClient.admin.products.get(
        id,
        {
          expand: [
            'variants',
            'images',
            'option_types',
            'taxons',
            'shipping_category',
            'tax_category',
          ],
        },
        { token: token! },
      ),
    enabled: !!token && !!id,
  })
}

export function useUpdateProduct() {
  const { token } = useAuth()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, ...params }: { id: string } & Record<string, unknown>) =>
      spreeClient.admin.products.update(id, params, { token: token! }),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['products', variables.id] })
      queryClient.invalidateQueries({ queryKey: ['products'] })
    },
  })
}

export function useDeleteProduct() {
  const { token } = useAuth()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) => spreeClient.admin.products.delete(id, { token: token! }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products'] })
    },
  })
}
