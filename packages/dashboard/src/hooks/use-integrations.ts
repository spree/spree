import type {
  Integration,
  IntegrationCreateParams,
  IntegrationUpdateParams,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useMutation, useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

/** Integrations connected to the current store, with secrets masked. */
export function useIntegrations() {
  return useQuery({
    queryKey: useResourceKey('integrations'),
    queryFn: () => adminClient.integrations.list({ limit: 100 }),
  })
}

/** Registered integration types and their configuration schemas — static registry discovery, cached long. */
export function useIntegrationTypes() {
  return useQuery({
    queryKey: useResourceKey('integrations', 'types'),
    queryFn: () => adminClient.integrations.types(),
    staleTime: 1000 * 60 * 30,
  })
}

/**
 * Connects an integration type to the store. Activating verifies the
 * connection server-side.
 *
 * Provider discovery is invalidated alongside: a carrier's rate and
 * fulfillment providers only become selectable once its integration is
 * connected, and those lists cache for half an hour.
 */
export function useCreateIntegration() {
  return useResourceMutation<Integration, Error, IntegrationCreateParams>({
    mutationFn: (params) => adminClient.integrations.create(params),
    invalidate: [['integrations'], ['delivery-methods']],
    successMessage: i18n.t('admin.integrations.messages.connected'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

/** Updates credentials or activation. Masked secrets round-trip safely. */
export function useUpdateIntegration(id: string) {
  return useResourceMutation<Integration, Error, IntegrationUpdateParams>({
    mutationFn: (params) => adminClient.integrations.update(id, params),
    invalidate: [['integrations'], ['delivery-methods']],
    successMessage: i18n.t('admin.integrations.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/** Disconnects an integration, deleting its stored credentials. */
export function useDeleteIntegration() {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.integrations.delete(id),
    invalidate: [['integrations'], ['delivery-methods']],
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
