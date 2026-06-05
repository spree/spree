import type { Channel, ChannelCreateParams, ChannelUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

interface UseChannelsParams {
  page?: number
  limit?: number
  expand?: string[]
}

export function useChannels({ page = 1, limit = 100, expand }: UseChannelsParams = {}) {
  return useQuery({
    queryKey: useResourceKey('channels', { page, limit, expand: expand?.join(',') ?? '' }),
    queryFn: () => adminClient.channels.list({ page, limit, ...(expand ? { expand } : {}) }),
    staleTime: 1000 * 60 * 5,
  })
}

export function useChannel(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('channels', id ?? 'noop'),
    queryFn: () => adminClient.channels.get(id as string),
    enabled: !!id,
  })
}

export function useCreateChannel() {
  return useResourceMutation<Channel, Error, ChannelCreateParams>({
    mutationFn: (params) => adminClient.channels.create(params),
    invalidate: [['channels']],
    successMessage: 'Channel created',
    errorMessage: 'Failed to create channel',
  })
}

export function useUpdateChannel(id: string) {
  return useResourceMutation<Channel, Error, ChannelUpdateParams>({
    mutationFn: (params) => adminClient.channels.update(id, params),
    invalidate: [['channels'], ['channels', id]],
    successMessage: 'Channel updated',
    errorMessage: 'Failed to update channel',
  })
}

export function useDeleteChannel() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.channels.delete(id),
    invalidate: [['channels']],
    successMessage: 'Channel deleted',
    errorMessage: 'Failed to delete channel',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('channels', id) })
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
