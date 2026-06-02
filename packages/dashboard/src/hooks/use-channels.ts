import type { Channel, ChannelCreateParams, ChannelUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceMutation, useStore } from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

// Channels are store-scoped on the backend (`for_store(current_store)`), so
// query keys MUST include the storeId — otherwise switching stores within
// the staleTime window serves the previous store's channels. The hooks read
// storeId from <StoreProvider> at call time.
export function channelsQueryKey(storeId: string) {
  return ['channels', storeId] as const
}

export function channelQueryKey(storeId: string, id: string) {
  return ['channels', storeId, id] as const
}

interface UseChannelsParams {
  page?: number
  limit?: number
  expand?: string[]
}

export function useChannels({ page = 1, limit = 100, expand }: UseChannelsParams = {}) {
  const { storeId } = useStore()
  return useQuery({
    queryKey: [...channelsQueryKey(storeId), { page, limit, expand: expand?.join(',') ?? '' }],
    queryFn: () => adminClient.channels.list({ page, limit, ...(expand ? { expand } : {}) }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useChannel(id: string | undefined) {
  const { storeId } = useStore()
  return useQuery({
    queryKey: id ? channelQueryKey(storeId, id) : ['channels', storeId, 'noop'],
    queryFn: () => adminClient.channels.get(id as string),
    enabled: !!id,
  })
}

export function useCreateChannel() {
  const { storeId } = useStore()
  return useResourceMutation<Channel, Error, ChannelCreateParams>({
    mutationFn: (params) => adminClient.channels.create(params),
    invalidate: [channelsQueryKey(storeId)],
    successMessage: 'Channel created',
    errorMessage: 'Failed to create channel',
  })
}

export function useUpdateChannel(id: string) {
  const { storeId } = useStore()
  return useResourceMutation<Channel, Error, ChannelUpdateParams>({
    mutationFn: (params) => adminClient.channels.update(id, params),
    invalidate: [channelsQueryKey(storeId), channelQueryKey(storeId, id)],
    successMessage: 'Channel updated',
    errorMessage: 'Failed to update channel',
  })
}

export function useDeleteChannel() {
  const queryClient = useQueryClient()
  const { storeId } = useStore()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.channels.delete(id),
    invalidate: [channelsQueryKey(storeId)],
    successMessage: 'Channel deleted',
    errorMessage: 'Failed to delete channel',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: channelQueryKey(storeId, id) })
    },
  })
}

export function channelAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) => adminClient.channels.list({ name_cont: q, limit: 20, sort: 'name' }),
    hydrate: (ids: string[]) => adminClient.channels.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Channel) => c.name ?? c.code ?? c.id,
    placeholder: i18n.t('admin.pages.channels.search_placeholder'),
    emptyText: i18n.t('admin.pages.channels.no_channels_found'),
  }
}
