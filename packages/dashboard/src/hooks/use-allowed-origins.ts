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
    successMessage: 'Allowed origin added',
    errorMessage: 'Failed to add allowed origin',
  })
}

export function useUpdateAllowedOrigin(id: string) {
  return useResourceMutation<AllowedOrigin, Error, AllowedOriginUpdateParams>({
    mutationFn: (params) => adminClient.allowedOrigins.update(id, params),
    invalidate: [['allowed-origins'], ['allowed-origins', id]],
    successMessage: 'Allowed origin updated',
    errorMessage: 'Failed to update allowed origin',
  })
}

export function useDeleteAllowedOrigin() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.allowedOrigins.delete(id),
    invalidate: [['allowed-origins']],
    successMessage: 'Allowed origin removed',
    errorMessage: 'Failed to remove allowed origin',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('allowed-origins', id) })
    },
  })
}
