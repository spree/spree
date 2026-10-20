import type { Channel, ChannelCreateParams, ChannelUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  listAllChannels,
  STORE_CONFIG_STALE_TIME,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

/**
 * Every channel of the store, fetched once and shared with the channel list
 * filter. Channel writes invalidate it.
 */
export function useChannels() {
  return useQuery({
    queryKey: useResourceKey('channels', 'all'),
    queryFn: listAllChannels,
    staleTime: STORE_CONFIG_STALE_TIME,
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
    successMessage: i18n.t('admin.channels.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateChannel(id: string) {
  return useResourceMutation<Channel, Error, ChannelUpdateParams>({
    mutationFn: (params) => adminClient.channels.update(id, params),
    invalidate: [['channels'], ['channels', id]],
    successMessage: i18n.t('admin.channels.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteChannel() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.channels.delete(id),
    invalidate: [['channels']],
    successMessage: i18n.t('admin.channels.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('channels', id) })
    },
  })
}

/**
 * Channel picker. List filters call it bare, so they read the shared list
 * above; form pickers pass their own key and search as the operator types.
 */
export function channelAutocompleteProps(queryKey = 'channels') {
  return {
    queryKey,
    staleTime: STORE_CONFIG_STALE_TIME,
    listAll: listAllChannels,
    search: (q: string) =>
      adminClient.channels.list({
        search: q,
        limit: 100,
        sort: 'name',
        fields: ['name', 'code'],
      }),
    hydrate: (ids: string[]) => adminClient.channels.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (c: Channel) => c.name ?? c.code ?? c.id,
    placeholder: i18n.t('admin.pages.channels.search_placeholder'),
    emptyText: i18n.t('admin.pages.channels.no_channels_found'),
  }
}
