import type {
  Integration,
  IntegrationCreateParams,
  IntegrationUpdateParams,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useMutation, useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

export function useIntegrations() {
  return useQuery({
    queryKey: useResourceKey('integrations'),
    queryFn: () => adminClient.integrations.list({ limit: 100 }),
  })
}

export function useIntegrationTypes() {
  return useQuery({
    queryKey: useResourceKey('integrations', 'types'),
    queryFn: () => adminClient.integrations.types(),
    staleTime: 1000 * 60 * 30,
  })
}

export function useCreateIntegration() {
  return useResourceMutation<Integration, Error, IntegrationCreateParams>({
    mutationFn: (params) => adminClient.integrations.create(params),
    invalidate: [['integrations']],
    successMessage: i18n.t('admin.integrations.messages.connected'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateIntegration(id: string) {
  return useResourceMutation<Integration, Error, IntegrationUpdateParams>({
    mutationFn: (params) => adminClient.integrations.update(id, params),
    invalidate: [['integrations']],
    successMessage: i18n.t('admin.integrations.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteIntegration() {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.integrations.delete(id),
    invalidate: [['integrations']],
    successMessage: i18n.t('admin.integrations.messages.disconnected'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

// Plain mutation: the result is displayed inline in the sheet, not toasted —
// a failed check is expected output, not an error condition.
export function useTestIntegration() {
  return useMutation({
    mutationFn: (id: string) => adminClient.integrations.test(id),
  })
}
