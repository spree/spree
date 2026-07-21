import type {
  OrderRoutingRule,
  OrderRoutingRuleCreateParams,
  OrderRoutingRuleUpdateParams,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'
import i18n from 'i18next'

export function useOrderRoutingRules(channelId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('channels', channelId ?? 'noop', 'order-routing-rules'),
    queryFn: () =>
      adminClient.channels.orderRoutingRules.list(channelId as string, {
        limit: 100,
        sort: 'position',
      }),
    enabled: !!channelId,
  })
}

// The rule-kind registry is static at runtime — cache forever, not store-scoped.
export function useOrderRoutingRuleTypes() {
  return useQuery({
    queryKey: ['order-routing-rules', 'types'],
    queryFn: () => adminClient.orderRoutingRules.types(),
    staleTime: Number.POSITIVE_INFINITY,
  })
}

export function useCreateOrderRoutingRule(channelId: string) {
  return useResourceMutation<OrderRoutingRule, Error, OrderRoutingRuleCreateParams>({
    mutationFn: (params) => adminClient.channels.orderRoutingRules.create(channelId, params),
    invalidate: [['channels', channelId, 'order-routing-rules']],
    successMessage: i18n.t('admin.order_routing_rules.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateOrderRoutingRule(channelId: string) {
  return useResourceMutation<
    OrderRoutingRule,
    Error,
    { id: string; params: OrderRoutingRuleUpdateParams }
  >({
    mutationFn: ({ id, params }) =>
      adminClient.channels.orderRoutingRules.update(channelId, id, params),
    invalidate: [['channels', channelId, 'order-routing-rules']],
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteOrderRoutingRule(channelId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.channels.orderRoutingRules.delete(channelId, id),
    invalidate: [['channels', channelId, 'order-routing-rules']],
    successMessage: i18n.t('admin.order_routing_rules.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}
