import type { PaymentMethodCreateParams, PaymentMethodUpdateParams } from '@spree/admin-sdk'
import { CAPTURE_METHODS } from '@spree/core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

// Empty means "inherit from the store" — the API models that as null, so the
// form's empty option maps back to null on submit.
export const CAPTURE_METHOD_OVERRIDES = ['', ...CAPTURE_METHODS] as const

/**
 * One checkout condition as held in form state. `id` is absent for rules
 * added in this editing session; dropping a rule from the array deletes it.
 */
export const paymentMethodRuleSchema = z.object({
  id: z.string().optional(),
  type: z.string(),
  active: z.boolean(),
  preferences: z.record(z.string(), z.unknown()),
})

export type PaymentMethodRuleDraft = z.infer<typeof paymentMethodRuleSchema>

export const paymentMethodBaseFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  description: z.string().optional(),
  storefront_visible: z.boolean(),
  active: z.boolean(),
  capture_method: z.enum(CAPTURE_METHOD_OVERRIDES),
  // Provider STI shorthand (e.g. `stripe`). Only set in create mode; the
  // top-level type is optional on the shared shape and required on the
  // create-only schema below.
  type: z.string().optional(),
  rules: z.array(paymentMethodRuleSchema),
})

export const paymentMethodCreateFormSchema = paymentMethodBaseFormSchema.extend({
  type: z.string().min(1, { error: requiredMessage('payment_method.type') }),
})

export type PaymentMethodFormValues = z.infer<typeof paymentMethodBaseFormSchema>

export const PAYMENT_METHOD_BASE_DEFAULTS: PaymentMethodFormValues = {
  name: '',
  description: '',
  storefront_visible: true,
  active: true,
  capture_method: '',
  rules: [],
}

export const PAYMENT_METHOD_CREATE_DEFAULTS: PaymentMethodFormValues = {
  ...PAYMENT_METHOD_BASE_DEFAULTS,
  type: '',
}

/** Wire `type` values that must not appear in the add-payment-method provider picker. */
export const PAYMENT_METHOD_TYPES_HIDDEN_FROM_PICKER = ['custom_payment_source_method'] as const

/** Providers that only simulate payments, for trying checkout without moving money. */
const TEST_GATEWAY_TYPES: readonly string[] = ['bogus']

export function isTestGateway(type: string) {
  return TEST_GATEWAY_TYPES.includes(type)
}

/**
 * The providers a merchant may add. One already installed stays listed: a
 * second record of a provider is how a store runs a second account.
 */
export function filterPaymentMethodProviderTypes<T extends { type: string }>(types: T[]): T[] {
  const hidden = new Set<string>(PAYMENT_METHOD_TYPES_HIDDEN_FROM_PICKER)
  return types.filter((entry) => !hidden.has(entry.type))
}

export function paymentMethodValuesToCreateParams(
  v: PaymentMethodFormValues,
  preferences: Record<string, unknown>,
): PaymentMethodCreateParams {
  // Schema should have already rejected this — guard against a misuse path
  // that would otherwise send an empty `type` and let the server 422.
  if (!v.type) throw new Error('payment method type is required')
  return {
    type: v.type,
    name: v.name,
    description: v.description?.length ? v.description : null,
    active: v.active,
    capture_method: v.capture_method || null,
    storefront_visible: v.storefront_visible,
    ...(Object.keys(preferences).length > 0 ? { preferences } : {}),
    ...(v.rules.length > 0 ? { rules: v.rules } : {}),
  }
}

export function paymentMethodValuesToUpdateParams(
  v: PaymentMethodFormValues,
): PaymentMethodUpdateParams {
  return {
    name: v.name,
    description: v.description?.length ? v.description : null,
    active: v.active,
    capture_method: v.capture_method || null,
    storefront_visible: v.storefront_visible,
    rules: v.rules,
  }
}
