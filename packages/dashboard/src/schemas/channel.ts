import type { ChannelCreateParams, ChannelUpdateParams } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { z } from 'zod/v4'

// Empty string clears the channel-level override → falls back to store.
export const ORDER_ROUTING_STRATEGY_VALUES = [
  '',
  'Spree::OrderRouting::Strategy::Rules',
  'Spree::OrderRouting::Strategy::Legacy',
] as const

export type OrderRoutingStrategyValue = (typeof ORDER_ROUTING_STRATEGY_VALUES)[number]

export const channelFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  code: z
    .string()
    .regex(/^[a-z0-9_-]*$/i, {
      error: () => i18n.t('admin.pages.channels.validation.code_format'),
    })
    .optional(),
  active: z.boolean(),
  default: z.boolean(),
  preferred_order_routing_strategy: z.string(),
})

export type ChannelFormValues = z.infer<typeof channelFormSchema>

export const CHANNEL_DEFAULTS: ChannelFormValues = {
  name: '',
  code: '',
  active: true,
  default: false,
  preferred_order_routing_strategy: '',
}

export function channelValuesToParams(
  v: ChannelFormValues,
): ChannelCreateParams & ChannelUpdateParams {
  return {
    name: v.name,
    ...(v.code ? { code: v.code } : {}),
    active: v.active,
    default: v.default,
    preferred_order_routing_strategy: v.preferred_order_routing_strategy || null,
  }
}
