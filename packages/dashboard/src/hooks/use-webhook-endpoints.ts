import type {
  WebhookDelivery,
  WebhookEndpoint,
  WebhookEndpointCreateParams,
  WebhookEndpointUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

export function useWebhookEndpoint(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('webhook-endpoints', id ?? 'noop'),
    queryFn: () => adminClient.webhookEndpoints.get(id as string),
    enabled: !!id,
  })
}

export function useCreateWebhookEndpoint() {
  return useResourceMutation<WebhookEndpoint, Error, WebhookEndpointCreateParams>({
    mutationFn: (params) => adminClient.webhookEndpoints.create(params),
    invalidate: [['webhook-endpoints']],
    // The creator wants the dedicated "save your secret" sheet, not a toast,
    // because the secret_key in the response is only revealed once.
    successMessage: false,
    errorMessage: 'Failed to create webhook endpoint',
  })
}

export function useUpdateWebhookEndpoint(id: string) {
  return useResourceMutation<WebhookEndpoint, Error, WebhookEndpointUpdateParams>({
    mutationFn: (params) => adminClient.webhookEndpoints.update(id, params),
    invalidate: [['webhook-endpoints'], ['webhook-endpoints', id]],
    successMessage: 'Webhook endpoint updated',
    errorMessage: 'Failed to update webhook endpoint',
  })
}

export function useDeleteWebhookEndpoint() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.webhookEndpoints.delete(id),
    invalidate: [['webhook-endpoints']],
    successMessage: 'Webhook endpoint removed',
    errorMessage: 'Failed to remove webhook endpoint',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('webhook-endpoints', id) })
    },
  })
}

export function useToggleWebhookEndpoint() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<WebhookEndpoint, Error, { id: string; active: boolean }>({
    mutationFn: ({ id, active }) =>
      active ? adminClient.webhookEndpoints.enable(id) : adminClient.webhookEndpoints.disable(id),
    invalidate: [['webhook-endpoints']],
    successMessage: false,
    errorMessage: 'Failed to update endpoint',
    onSuccess: (_data, { id }) => {
      // Detail page reads `disabled_at` + `active` directly from the
      // single-endpoint cache; invalidating only the list misses it.
      queryClient.invalidateQueries({ queryKey: buildKey('webhook-endpoints', id) })
    },
  })
}

export function useSendTestWebhook() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<WebhookDelivery, Error, string>({
    mutationFn: (id) => adminClient.webhookEndpoints.sendTest(id),
    successMessage: false,
    errorMessage: 'Failed to send test webhook',
    onSuccess: (_data, endpointId) => {
      // Refetch the deliveries list embedded in the detail page (the new test
      // row needs to appear without a manual refresh) and the endpoint's
      // detail cache (total/successful/failed counts + last_delivery_at).
      queryClient.invalidateQueries({ queryKey: buildKey('webhook-deliveries', endpointId) })
      queryClient.invalidateQueries({ queryKey: buildKey('webhook-endpoints', endpointId) })
    },
  })
}

export function useWebhookDelivery(endpointId: string | undefined, deliveryId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey(
      'webhook-endpoints',
      endpointId ?? 'noop',
      'deliveries',
      deliveryId ?? 'noop',
    ),
    queryFn: () =>
      adminClient.webhookEndpoints.deliveries.get(endpointId as string, deliveryId as string),
    enabled: !!endpointId && !!deliveryId,
  })
}

export function useRedeliverWebhookDelivery(endpointId: string) {
  return useResourceMutation<WebhookDelivery, Error, string>({
    mutationFn: (deliveryId) =>
      adminClient.webhookEndpoints.deliveries.redeliver(endpointId, deliveryId),
    invalidate: [
      // The deliveries table queried via ResourceTable + the endpoint's
      // detail cache (totals + last_delivery_at).
      ['webhook-deliveries', endpointId],
      ['webhook-endpoints', endpointId],
    ],
    successMessage: false,
    errorMessage: 'Failed to redeliver',
  })
}
