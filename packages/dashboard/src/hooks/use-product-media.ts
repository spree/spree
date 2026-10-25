import type { Media, MediaCreateParams, MediaUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

type MediaListSnapshot = { data: Media[] }

/**
 * Every media item of a product, across pages. The media card edits the
 * whole list at once and a save re-baselines the form from it, so reading
 * one page would silently drop the rest from the form.
 */
export async function listAllProductMedia(productId: string) {
  const first = await adminClient.products.media.list(productId, { limit: 100 })
  const data = [...first.data]
  for (let page = 2; page <= first.meta.pages; page++) {
    data.push(...(await adminClient.products.media.list(productId, { limit: 100, page })).data)
  }
  return { ...first, data }
}

export function useProductMedia(productId: string) {
  return useQuery({
    queryKey: useResourceKey('products', productId, 'media'),
    queryFn: () => listAllProductMedia(productId),
    enabled: !!productId,
  })
}

export function useCreateProductMedia(productId: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (params: MediaCreateParams) => adminClient.products.media.create(productId, params),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: buildKey('products', productId, 'media') })
      queryClient.invalidateQueries({ queryKey: buildKey('products', productId) })
      if (variables.variant_ids !== undefined) {
        queryClient.invalidateQueries({ queryKey: buildKey('products', productId, 'variants') })
      }
    },
  })
}

export function useUpdateProductMedia(productId: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  const queryKey = buildKey('products', productId, 'media')

  return useMutation({
    mutationFn: ({ id, ...params }: MediaUpdateParams & { id: string }) =>
      adminClient.products.media.update(productId, id, params),

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
        queryClient.invalidateQueries({ queryKey: buildKey('products', productId, 'variants') })
      }
    },
  })
}

export function useDeleteProductMedia(productId: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (id: string) => adminClient.products.media.delete(productId, id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey('products', productId, 'media') })
      queryClient.invalidateQueries({ queryKey: buildKey('products', productId) })
    },
  })
}
