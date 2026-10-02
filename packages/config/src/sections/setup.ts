import type {
  AllowedOrigin as SdkAllowedOrigin,
  ApiKey as SdkApiKey,
  ClaimReason as SdkClaimReason,
  CommissionRate as SdkCommissionRate,
  OrderCancellationReason as SdkOrderCancellationReason,
  PaymentMethod as SdkPaymentMethod,
  RefundReason as SdkRefundReason,
  ReturnReason as SdkReturnReason,
  SellerRequirement as SdkSellerRequirement,
} from '@spree/admin-sdk'
import {
  ALLOWED_ORIGIN_ATTRIBUTES,
  type AllowedOriginEntry,
  API_KEY_ATTRIBUTES,
  type ApiKeyEntry,
  COMMISSION_RATE_ATTRIBUTES,
  type CommissionRateEntry,
  PAYMENT_METHOD_ATTRIBUTES,
  type PaymentMethodEntry,
  REASON_ATTRIBUTES,
  type ReasonEntry,
  SELLER_REQUIREMENT_ATTRIBUTES,
  type SellerRequirementEntry,
} from '../schema.js'
import type { LiveRecord, SectionName } from '../types.js'
import { type Payload, pick, plainSection, scalarPreferences } from './section.js'

// The SDK's generated types plus the index signature, so a section can read
// both declared attributes and the associations an `expand` adds.
type AllowedOrigin = SdkAllowedOrigin & LiveRecord
type ApiKey = SdkApiKey & LiveRecord
type CommissionRate = SdkCommissionRate & LiveRecord
type PaymentMethod = SdkPaymentMethod & LiveRecord
type SellerRequirement = SdkSellerRequirement & LiveRecord
type Reason = (SdkReturnReason | SdkClaimReason | SdkRefundReason | SdkOrderCancellationReason) &
  LiveRecord

/**
 * Payment methods match on name. The type is set on create and never
 * changes; gateway credentials are not written from the file.
 */
export const paymentMethods = plainSection<PaymentMethodEntry, PaymentMethod>({
  name: 'payment_methods',
  scope: 'write_settings',
  introspectByDefault: true,
  key: 'name',
  attributes: PAYMENT_METHOD_ATTRIBUTES,
  defaults: { active: true, storefront_visible: true },
  fixedOnCreate: ['type'],
  typesPath: '/payment_methods/types',
  async desired(entry) {
    return { ...pick(entry, PAYMENT_METHOD_ATTRIBUTES), type: entry.type }
  },
  async toFile(live) {
    return {
      ...pick(live as unknown as PaymentMethodEntry, PAYMENT_METHOD_ATTRIBUTES),
      type: String(live.type),
    } as PaymentMethodEntry
  },
})

const reasons = (name: SectionName & `${string}_reasons`) =>
  plainSection<ReasonEntry, Reason>({
    name,
    scope: 'write_settings',
    introspectByDefault: true,
    key: 'name',
    attributes: REASON_ATTRIBUTES,
    defaults: { active: true },
  })

export const returnReasons = reasons('return_reasons')
export const claimReasons = reasons('claim_reasons')
export const refundReasons = reasons('refund_reasons')
export const orderCancellationReasons = reasons('order_cancellation_reasons')

export const commissionRates = plainSection<CommissionRateEntry, CommissionRate>({
  name: 'commission_rates',
  scope: 'write_commissions',
  introspectByDefault: true,
  key: 'code',
  attributes: COMMISSION_RATE_ATTRIBUTES,
})

/**
 * One requirement per kind, matched on its type shorthand (the API reads it
 * back as `kind`). The type is fixed once the requirement exists.
 */
export const sellerRequirements = plainSection<SellerRequirementEntry, SellerRequirement>({
  name: 'seller_requirements',
  scope: 'write_sellers',
  introspectByDefault: true,
  key: 'type',
  keyAttribute: 'kind',
  // The list filters on the stored class name, not the shorthand the file
  // uses, so the section is listed whole.
  filterable: false,
  attributes: SELLER_REQUIREMENT_ATTRIBUTES,
  fixedOnCreate: ['type'],
  typesPath: '/seller_requirements/types',
  async desired(entry) {
    const payload: Payload = pick(entry, SELLER_REQUIREMENT_ATTRIBUTES)
    if (entry.preferences) payload.preferences = entry.preferences
    return payload
  },
  async current(live) {
    return { ...live, type: live.kind }
  },
  async toFile(live) {
    const preferences = scalarPreferences(live.preferences ?? {})
    return {
      type: String(live.kind),
      required: live.required,
      active: live.active,
      ...(Object.keys(preferences).length ? { preferences } : {}),
    } as SellerRequirementEntry
  },
})

/**
 * Keys match on name and are created once: the API lets only the name
 * change afterwards, and the token is never written to the file.
 */
export const apiKeys = plainSection<ApiKeyEntry, ApiKey>({
  name: 'api_keys',
  scope: 'write_api_keys',
  pruneRefusal: 'revoking a key from a file would cut off whatever uses it; revoke keys one by one',
  introspectByDefault: false,
  key: 'name',
  attributes: API_KEY_ATTRIBUTES,
  references: (config) => ({
    channels: (config.api_keys ?? []).flatMap((key) => key.channel ?? []),
  }),
  async desired(entry, ctx, path) {
    const payload: Payload = pick(entry, API_KEY_ATTRIBUTES)
    if (entry.channel) payload.channel_id = await ctx.ref('channels', entry.channel, path)
    return payload
  },
  // A live key is never rewritten, so it always reads as unchanged.
  async current(_live, _ctx, desired) {
    return desired
  },
  async toFile(live, ctx) {
    const channel = live.channel_id ? await ctx.keyOf('channels', String(live.channel_id)) : null
    return {
      name: live.name,
      key_type: live.key_type,
      ...(live.scopes?.length ? { scopes: live.scopes } : {}),
      ...(channel ? { channel } : {}),
    } as ApiKeyEntry
  },
})

export const allowedOrigins = plainSection<AllowedOriginEntry, AllowedOrigin>({
  name: 'allowed_origins',
  scope: 'write_settings',
  introspectByDefault: true,
  key: 'origin',
  attributes: ALLOWED_ORIGIN_ATTRIBUTES,
})
