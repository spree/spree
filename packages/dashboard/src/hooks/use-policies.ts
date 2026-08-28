import type { Policy, PolicyCreateParams, PolicyUpdateParams } from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

// No `usePolicies` list hook: the settings page reads the collection through
// `ResourceTable`, which paginates. A convenience hook here would have to pick
// a page size, and every such hook so far has picked one and silently dropped
// whatever came after it.

export function usePolicy(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('policies', id ?? 'noop'),
    queryFn: () => adminClient.policies.get(id as string),
    enabled: !!id,
  })
}

export function useCreatePolicy() {
  return useResourceMutation<Policy, Error, PolicyCreateParams>({
    mutationFn: (params) => adminClient.policies.create(params),
    invalidate: [['policies']],
    successMessage: i18n.t('admin.policies.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdatePolicy(id: string) {
  return useResourceMutation<Policy, Error, PolicyUpdateParams>({
    mutationFn: (params) => adminClient.policies.update(id, params),
    invalidate: [['policies'], ['policies', id]],
    successMessage: i18n.t('admin.policies.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeletePolicy() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.policies.delete(id),
    invalidate: [['policies']],
    successMessage: i18n.t('admin.policies.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('policies', id) })
    },
  })
}
