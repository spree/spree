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

/**
 * Mutation hook to update an API key. Only `name` is editable — scopes and
 * key_type are fixed at creation; to change a key's authority, create a new key
 * and revoke the old one.
 *
 * @param variables.id Prefixed API key id (e.g. `key_xxx`).
 * @param variables.params Update payload — `{ name }`.
 * @returns A TanStack mutation; on success it invalidates the `api-keys` query.
 *   Toasts are suppressed (`successMessage`/`errorMessage` false) so the calling
 *   form owns success/error feedback (422s map onto field errors).
 */
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
