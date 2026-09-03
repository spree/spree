import type { ChannelCreateParams, ChannelUpdateParams } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import i18n from 'i18next'
import { z } from 'zod/v4'

// Empty string clears the channel-level override → falls back to store.
export const RULES_ORDER_ROUTING_STRATEGY = 'Spree::OrderRouting::Strategy::Rules'

export const ORDER_ROUTING_STRATEGY_VALUES = [
  '',
  RULES_ORDER_ROUTING_STRATEGY,
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
  // Empty means shoppers outside any assigned catalog see every product
  // published on the channel.
  default_catalog_id: z.string(),
  // Empty means every location of the store serves this channel, which is how
  // the API reads an empty array.
  stock_location_ids: z.array(z.string()),
  // Empty means the channel sells into every market of the store.
  market_ids: z.array(z.string()),
  // Empty derives the default from the allowlist; see resolved_default_market.
  default_market_id: z.string(),
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
  default_catalog_id: '',
  stock_location_ids: [],
  market_ids: [],
  default_market_id: '',
}

/**
 * Maps form values to the Admin API payload. Every blank override is sent as
 * null rather than omitted: clearing a field on an existing channel has to
 * restore the inherited behavior, which an omitted key would not do.
 */
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
    // '' → no default catalog: shoppers outside any assigned catalog see
    // every product published on the channel.
    default_catalog_id: v.default_catalog_id || null,
    // Replace-set: an empty array clears the narrowing, so the channel sells
    // into every market again.
    market_ids: v.market_ids,
    // '' → derive the default from the allowlist rather than pinning one.
    default_market_id: v.default_market_id || null,
    // Replace-set: an empty array clears the narrowing, so every location
    // serves the channel again.
    stock_location_ids: v.stock_location_ids,
  }
}
