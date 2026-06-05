import type {
  WebhookDelivery,
  WebhookEndpoint,
  WebhookEndpointCreateParams,
  WebhookEndpointUpdateParams,
} from '@spree/admin-sdk'
import { adminClient, useResourceMutation, useStore } from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'

// `webhookEndpointsListKey` is what `<ResourceTable queryKey="webhook-endpoints">`
// uses internally as the prefix of its compound key (`['webhook-endpoints',
// { page, limit, sort, search, filters }]`). Invalidating the bare prefix is
// what gets the table to refetch — anything more specific misses.
//
// Detail/deliveries queries below carry `storeId` so switching stores invalidates
// cached single-endpoint data; the list query is owned by ResourceTable, which
// remounts when the route changes, so it doesn't need explicit store-scoping.
export const webhookEndpointsListKey = ['webhook-endpoints'] as const

export function useWebhookEndpointQueryKey(id: string | undefined) {
  const { storeId } = useStore()
  return ['webhook-endpoints', storeId, id ?? 'noop'] as const
}

export function useWebhookDeliveriesQueryKey(endpointId: string | undefined) {
  const { storeId } = useStore()
  return ['webhook-endpoints', storeId, endpointId ?? 'noop', 'deliveries'] as const
}

export function useWebhookEndpoint(id: string | undefined) {
  const key = useWebhookEndpointQueryKey(id)
  return useQuery({
    queryKey: key,
    queryFn: () => adminClient.webhookEndpoints.get(id as string),
    enabled: !!id,
  })
}

export function useCreateWebhookEndpoint() {
  return useResourceMutation<WebhookEndpoint, Error, WebhookEndpointCreateParams>({
    mutationFn: (params) => adminClient.webhookEndpoints.create(params),
    invalidate: [webhookEndpointsListKey],
    // The creator wants the dedicated "save your secret" sheet, not a toast,
    // because the secret_key in the response is only revealed once.
    successMessage: false,
    errorMessage: 'Failed to create webhook endpoint',
  })
}

export function useUpdateWebhookEndpoint(id: string) {
  const detailKey = useWebhookEndpointQueryKey(id)

  return useResourceMutation<WebhookEndpoint, Error, WebhookEndpointUpdateParams>({
    mutationFn: (params) => adminClient.webhookEndpoints.update(id, params),
    invalidate: [webhookEndpointsListKey, detailKey],
    successMessage: 'Webhook endpoint updated',
    errorMessage: 'Failed to update webhook endpoint',
  })
}

export function useDeleteWebhookEndpoint() {
  const queryClient = useQueryClient()
  const { storeId } = useStore()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.webhookEndpoints.delete(id),
    invalidate: [webhookEndpointsListKey],
    successMessage: 'Webhook endpoint removed',
    errorMessage: 'Failed to remove webhook endpoint',
    onSuccess: (_data, id) => {
      queryClient.removeQueries({
        queryKey: ['webhook-endpoints', storeId, id],
      })
    },
  })
}

export function useToggleWebhookEndpoint() {
  const queryClient = useQueryClient()
  const { storeId } = useStore()

  return useResourceMutation<WebhookEndpoint, Error, { id: string; active: boolean }>({
    mutationFn: ({ id, active }) =>
      active ? adminClient.webhookEndpoints.enable(id) : adminClient.webhookEndpoints.disable(id),
    invalidate: [webhookEndpointsListKey],
    successMessage: false,
    errorMessage: 'Failed to update endpoint',
    onSuccess: (_data, { id }) => {
      // The detail page reads `disabled_at` + `active` directly from the
      // single-endpoint cache; invalidating only the list misses it.
      queryClient.invalidateQueries({
        queryKey: ['webhook-endpoints', storeId, id],
      })
    },
  })
}

export function useSendTestWebhook() {
  const queryClient = useQueryClient()
  const { storeId } = useStore()

  return useResourceMutation<WebhookDelivery, Error, string>({
    mutationFn: (id) => adminClient.webhookEndpoints.sendTest(id),
    successMessage: false,
    errorMessage: 'Failed to send test webhook',
    onSuccess: (_data, endpointId) => {
      // Refetch the deliveries list for the endpoint we just tested so the new
      // row appears without needing a manual refresh. The mutation is passed
      // the endpoint id as its variable, so we can derive the right key here.
      queryClient.invalidateQueries({
        queryKey: ['webhook-endpoints', storeId, endpointId, 'deliveries'],
      })
    },
  })
}

export function useWebhookDelivery(endpointId: string | undefined, deliveryId: string | undefined) {
  const { storeId } = useStore()
  return useQuery({
    queryKey: [
      'webhook-endpoints',
      storeId,
      endpointId ?? 'noop',
      'deliveries',
      deliveryId ?? 'noop',
    ] as const,
    queryFn: () =>
      adminClient.webhookEndpoints.deliveries.get(endpointId as string, deliveryId as string),
    enabled: !!endpointId && !!deliveryId,
  })
}

export function useRedeliverWebhookDelivery(endpointId: string) {
  const deliveriesKey = useWebhookDeliveriesQueryKey(endpointId)

  return useResourceMutation<WebhookDelivery, Error, string>({
    mutationFn: (deliveryId) =>
      adminClient.webhookEndpoints.deliveries.redeliver(endpointId, deliveryId),
    invalidate: [deliveriesKey],
    successMessage: false,
    errorMessage: 'Failed to redeliver',
  })
}
