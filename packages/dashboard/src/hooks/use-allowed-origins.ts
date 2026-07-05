import type {
  AllowedOrigin,
  AllowedOriginCreateParams,
  AllowedOriginUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useAllowedOrigin(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('allowed-origins', id ?? 'noop'),
    queryFn: () => adminClient.allowedOrigins.get(id as string),
    enabled: !!id,
  })
}

export function useCreateAllowedOrigin() {
  return useResourceMutation<AllowedOrigin, Error, AllowedOriginCreateParams>({
    mutationFn: (params) => adminClient.allowedOrigins.create(params),
    invalidate: [['allowed-origins']],
    successMessage: i18n.t('admin.allowed_origins.messages.added'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateAllowedOrigin(id: string) {
  return useResourceMutation<AllowedOrigin, Error, AllowedOriginUpdateParams>({
    mutationFn: (params) => adminClient.allowedOrigins.update(id, params),
    invalidate: [['allowed-origins'], ['allowed-origins', id]],
    successMessage: i18n.t('admin.allowed_origins.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteAllowedOrigin() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.allowedOrigins.delete(id),
    invalidate: [['allowed-origins']],
    successMessage: i18n.t('admin.allowed_origins.messages.removed'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('allowed-origins', id) })
    },
  })
}
