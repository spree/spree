import type { Media } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'

type MediaListSnapshot = { data: Media[] }

export function useProductMedia(productId: string) {
  return useQuery({
    queryKey: ['products', productId, 'media'],
    queryFn: () => adminClient.products.media.list(productId),
    enabled: !!productId,
  })
}

export function useCreateProductMedia(productId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (params: {
      signed_id: string
      alt?: string
      position?: number
      variant_ids?: string[]
    }) => adminClient.products.media.create(productId, params),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'media'] })
      queryClient.invalidateQueries({ queryKey: ['products', productId] })
      if (variables.variant_ids !== undefined) {
        queryClient.invalidateQueries({ queryKey: ['products', productId, 'variants'] })
      }
    },
  })
}

export function useUpdateProductMedia(productId: string) {
  const queryClient = useQueryClient()
  const queryKey = ['products', productId, 'media']

  return useMutation({
    mutationFn: ({
      id,
      ...params
    }: {
      id: string
      alt?: string
      position?: number
      variant_ids?: string[]
    }) => adminClient.products.media.update(productId, id, params),

    // Optimistically splice on `position` change — server-side acts_as_list
    // shifts siblings, so the post-success refetch will match.
    onMutate: async ({ id, position }) => {
      if (position === undefined) return undefined

      await queryClient.cancelQueries({ queryKey })
      const previous = queryClient.getQueryData<MediaListSnapshot>(queryKey)
      if (!previous) return undefined

      const items = [...previous.data]
      const fromIndex = items.findIndex((m) => m.id === id)
      if (fromIndex === -1) return { previous }

      const toIndex = Math.max(0, Math.min(items.length - 1, position - 1))
      const [moved] = items.splice(fromIndex, 1)
      items.splice(toIndex, 0, moved)

      queryClient.setQueryData<MediaListSnapshot>(queryKey, {
        ...previous,
        data: items,
      })

      return { previous }
    },

    onError: (_err, _vars, context) => {
      if (context?.previous) {
        queryClient.setQueryData(queryKey, context.previous)
      }
    },

    onSettled: (_data, _err, variables) => {
      queryClient.invalidateQueries({ queryKey })
      if (variables.variant_ids !== undefined) {
        queryClient.invalidateQueries({ queryKey: ['products', productId, 'variants'] })
      }
    },
  })
}

export function useDeleteProductMedia(productId: string) {
  const queryClient = useQueryClient()

  return useMutation({
    mutationFn: (id: string) => adminClient.products.media.delete(productId, id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', productId, 'media'] })
      queryClient.invalidateQueries({ queryKey: ['products', productId] })
    },
  })
}
