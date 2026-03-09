import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { spreeClient } from '@/client'
import { useAuth } from '@/hooks/use-auth'

export function useProductAssets(productId: string) {
  const { token } = useAuth()

  return useQuery({
    queryKey: ['products', productId, 'assets'],
    queryFn: () =>
      spreeClient.admin.products.assets.list(productId, {}, { token: token! }),
    enabled: !!token && !!productId,
  })
}

export function useCreateProductAsset(productId: string) {
  const { token } = useAuth()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: { signed_id: string; alt?: string; position?: number }) =>
      spreeClient.admin.products.assets.create(productId, params, { token: token! }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'assets'] })
      queryClient.invalidateQueries({ queryKey: ['products', productId] })
    },
  })
}

export function useUpdateProductAsset(productId: string) {
  const { token } = useAuth()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: ({ id, ...params }: { id: string; alt?: string; position?: number }) =>
      spreeClient.admin.products.assets.update(productId, id, params, { token: token! }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'assets'] })
    },
  })
}

export function useDeleteProductAsset(productId: string) {
  const { token } = useAuth()
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) =>
      spreeClient.admin.products.assets.delete(productId, id, { token: token! }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'assets'] })
      queryClient.invalidateQueries({ queryKey: ['products', productId] })
    },
  })
}
