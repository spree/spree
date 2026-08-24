import type {
  ListParams,
  Media,
  MediaLibraryCreateParams,
  MediaUpdateParams,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceKeyBuilder } from '@spree/dashboard-core'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'

export type MediaLibraryFilters = ListParams & Record<string, unknown>

export function useMediaLibrary(params?: MediaLibraryFilters) {
  return useQuery({
    queryKey: useResourceKey('media', params),
    queryFn: () => adminClient.media.list(params),
  })
}

/**
 * Where one file is in use. Only fetched when asked for, since answering it
 * searches stored descriptions — fine for one file on demand, not for a grid.
 */
export function useMediaUsage(id: string | null) {
  return useQuery({
    queryKey: useResourceKey('media', id ?? 'none', 'usage'),
    queryFn: () => adminClient.media.usage(id as string),
    enabled: !!id,
  })
}

export function useCreateMediaLibraryFile() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (params: MediaLibraryCreateParams) => adminClient.media.create(params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey('media') })
    },
  })
}

export function useUpdateMediaLibraryFile() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: ({ id, ...params }: MediaUpdateParams & { id: string }) =>
      adminClient.media.update(id, params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey('media') })
    },
  })
}

export function useDeleteMediaLibraryFile() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: ({ id, detach }: { id: string; detach?: boolean }) =>
      adminClient.media.delete(id, detach ? { detach: true } : undefined),
    onSuccess: (_data, { detach }) => {
      queryClient.invalidateQueries({ queryKey: buildKey('media') })
      // Detaching touched product galleries and category/collection images.
      if (detach) {
        queryClient.invalidateQueries({ queryKey: buildKey('products') })
        queryClient.invalidateQueries({ queryKey: buildKey('categories') })
        queryClient.invalidateQueries({ queryKey: buildKey('collections') })
      }
    },
  })
}

/**
 * Places a library file on a product. The new row shares the file rather than
 * copying it, so this uploads nothing.
 */
export function usePlaceMediaOnProduct(productId: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useMutation({
    mutationFn: (sourceMediaId: string) =>
      adminClient.products.media.create(productId, { source_media_id: sourceMediaId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: buildKey('products', productId, 'media') })
      queryClient.invalidateQueries({ queryKey: buildKey('products', productId) })
      // The file is now placed, which the library shows per row.
      queryClient.invalidateQueries({ queryKey: buildKey('media') })
    },
  })
}

/** A file is renderable as a picture; a video needs its poster to stand in. */
export function mediaThumbnailUrl(media: Media): string | null {
  return media.small_url ?? media.poster_url ?? media.original_url ?? null
}

/**
 * A larger rendition for surfaces that show one file at a time — the detail
 * panel, the edit sheet. The grid's 256px thumbnail pixelates at that width.
 */
export function mediaPreviewUrl(media: Media): string | null {
  return media.large_url ?? media.poster_url ?? media.original_url ?? mediaThumbnailUrl(media)
}
