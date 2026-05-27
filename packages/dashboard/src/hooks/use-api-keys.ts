import type { ApiKey, ApiKeyCreateParams } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'

const API_KEYS_KEY = ['api-keys'] as const

export function useApiKeys() {
  return useQuery({
    queryKey: API_KEYS_KEY,
    queryFn: () => adminClient.apiKeys.list({ limit: 100 }),
  })
}

export function useCreateApiKey() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (params: ApiKeyCreateParams) => adminClient.apiKeys.create(params),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: API_KEYS_KEY })
    },
  })
}

export function useRevokeApiKey() {
  const qc = useQueryClient()
  return useMutation<ApiKey, Error, string>({
    mutationFn: (id: string) => adminClient.apiKeys.revoke(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: API_KEYS_KEY })
    },
  })
}

export function useDeleteApiKey() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => adminClient.apiKeys.delete(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: API_KEYS_KEY })
    },
  })
}
