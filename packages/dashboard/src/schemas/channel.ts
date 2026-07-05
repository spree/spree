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

// Empty string clears the channel-level override → falls back to store.
export const STOREFRONT_ACCESS_VALUES = ['', 'public', 'prices_hidden', 'login_required'] as const

// Tri-state form representation of the channel's boolean guest_checkout
// override: '' inherits the store value, 'true'/'false' set an explicit value.
export const GUEST_CHECKOUT_VALUES = ['', 'true', 'false'] as const

export const channelFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  code: z
    .string()
    .regex(/^[a-z0-9_-]*$/, {
      error: () => i18n.t('admin.pages.channels.validation.code_format'),
    })
    .optional(),
  active: z.boolean(),
  default: z.boolean(),
  preferred_order_routing_strategy: z.string(),
  preferred_storefront_access: z.string(),
  preferred_guest_checkout: z.string(),
})

export type ChannelFormValues = z.infer<typeof channelFormSchema>

export const CHANNEL_DEFAULTS: ChannelFormValues = {
  name: '',
  code: '',
  active: true,
  default: false,
  preferred_order_routing_strategy: '',
  preferred_storefront_access: '',
  preferred_guest_checkout: '',
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
    preferred_storefront_access: v.preferred_storefront_access || null,
    // '' → inherit (null); otherwise an explicit boolean.
    preferred_guest_checkout:
      v.preferred_guest_checkout === '' ? null : v.preferred_guest_checkout === 'true',
  }
}
