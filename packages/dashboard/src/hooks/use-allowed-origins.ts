import type {
  AllowedOrigin,
  AllowedOriginCreateParams,
  AllowedOriginUpdateParams,
} from '@spree/admin-sdk'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'
import { useResourceMutation } from '@/hooks/use-resource-mutation'

export const allowedOriginsQueryKey = ['allowed-origins'] as const

export function allowedOriginQueryKey(id: string) {
  return ['allowed-origins', id] as const
}

export function useAllowedOrigin(id: string | undefined) {
  return useQuery({
    queryKey: id ? allowedOriginQueryKey(id) : ['allowed-origins', 'noop'],
    queryFn: () => adminClient.allowedOrigins.get(id as string),
    enabled: !!id,
  })
}

export function useCreateAllowedOrigin() {
  return useResourceMutation<AllowedOrigin, Error, AllowedOriginCreateParams>({
    mutationFn: (params) => adminClient.allowedOrigins.create(params),
    invalidate: [allowedOriginsQueryKey],
    successMessage: 'Allowed origin added',
    errorMessage: 'Failed to add allowed origin',
  })
}

export function useUpdateAllowedOrigin(id: string) {
  return useResourceMutation<AllowedOrigin, Error, AllowedOriginUpdateParams>({
    mutationFn: (params) => adminClient.allowedOrigins.update(id, params),
    invalidate: [allowedOriginsQueryKey, allowedOriginQueryKey(id)],
    successMessage: 'Allowed origin updated',
    errorMessage: 'Failed to update allowed origin',
  })
}

export function useDeleteAllowedOrigin() {
  const queryClient = useQueryClient()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.allowedOrigins.delete(id),
    invalidate: [allowedOriginsQueryKey],
    successMessage: 'Allowed origin removed',
    errorMessage: 'Failed to remove allowed origin',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: allowedOriginQueryKey(id) })
    },
  })
}
