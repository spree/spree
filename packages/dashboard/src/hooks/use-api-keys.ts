import type { ApiKey, ApiKeyCreateParams, ApiKeyUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useApiKeys() {
  return useQuery({
    queryKey: useResourceKey('api-keys'),
    queryFn: () => adminClient.apiKeys.list({ limit: 100 }),
  })
}

/**
 * The publishable key the storefront-connect flow displays — the oldest
 * active one, minted on first use for stores that have none (same policy as
 * the legacy admin storefront page).
 *
 * Lives under the `api-keys` namespace so key mutations elsewhere (create,
 * revoke on the API Keys settings page) invalidate it via their existing
 * `[['api-keys']]` prefix. `staleTime: Infinity` + `retry: false` because the
 * queryFn can mint a key — it must run once per cache lifetime, never repeat
 * on its own.
 */
export function useStorefrontPublishableKey({ enabled = true }: { enabled?: boolean } = {}) {
  return useQuery({
    queryKey: useResourceKey('api-keys', 'storefront-publishable'),
    enabled,
    staleTime: Number.POSITIVE_INFINITY,
    retry: false,
    queryFn: async () => {
      const { data: keys } = await adminClient.apiKeys.list({ limit: 100 })
      const existing = keys.find((key) => key.key_type === 'publishable' && !key.revoked_at)
      if (existing) return existing

      return adminClient.apiKeys.create({ name: 'Storefront', key_type: 'publishable' })
    },
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
