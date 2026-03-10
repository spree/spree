import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'

export function useProductAssets(productId: string) {
  return useQuery({
    queryKey: ['products', productId, 'assets'],
    queryFn: () => adminClient.products.assets.list(productId),
    enabled: !!productId,
  })
}

export function useCreateProductAsset(productId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: { signed_id: string; alt?: string; position?: number }) =>
      adminClient.products.assets.create(productId, params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'assets'] })
      queryClient.invalidateQueries({ queryKey: ['products', productId] })
    },
  })
}

export function useUpdateProductAsset(productId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, ...params }: { id: string; alt?: string; position?: number }) =>
      adminClient.products.assets.update(productId, id, params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'assets'] })
    },
  })
}

export function useDeleteProductAsset(productId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) =>
      adminClient.products.assets.delete(productId, id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'assets'] })
      queryClient.invalidateQueries({ queryKey: ['products', productId] })
    },
  })
}
