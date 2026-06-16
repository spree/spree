import type { ApiKey, ApiKeyCreateParams, ApiKeyUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useApiKeys() {
  return useQuery({
    queryKey: useResourceKey('api-keys'),
    queryFn: () => adminClient.apiKeys.list({ limit: 100 }),
  })
}

export function useCreateApiKey() {
  return useResourceMutation<ApiKey, Error, ApiKeyCreateParams>({
    mutationFn: (params) => adminClient.apiKeys.create(params),
    invalidate: [['api-keys']],
    successMessage: false,
    errorMessage: false,
  })
}

// Only `name` is editable — scopes and key_type are fixed at creation. To change
// a key's authority, create a new key and revoke the old one.
export function useUpdateApiKey() {
  return useResourceMutation<ApiKey, Error, { id: string; params: ApiKeyUpdateParams }>({
    mutationFn: ({ id, params }) => adminClient.apiKeys.update(id, params),
    invalidate: [['api-keys']],
    successMessage: false,
    errorMessage: false,
  })
}

export function useRevokeApiKey() {
  return useResourceMutation<ApiKey, Error, string>({
    mutationFn: (id) => adminClient.apiKeys.revoke(id),
    invalidate: [['api-keys']],
    successMessage: false,
    errorMessage: false,
  })
}

export function useDeleteApiKey() {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.apiKeys.delete(id),
    invalidate: [['api-keys']],
    successMessage: false,
    errorMessage: false,
  })
}
