import type { ApiKey, ApiKeyCreateParams } from '@spree/admin-sdk'
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
