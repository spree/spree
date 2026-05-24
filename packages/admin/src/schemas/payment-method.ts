import type { PaymentMethodCreateParams, PaymentMethodUpdateParams } from '@spree/admin-sdk'
import { z } from 'zod/v4'
import { requiredMessage } from '@/lib/validation-messages'

export const paymentMethodBaseFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  description: z.string().optional(),
  storefront_visible: z.boolean(),
  active: z.boolean(),
  auto_capture: z.boolean(),
  // Provider STI shorthand (e.g. `stripe`). Only set in create mode; the
  // top-level type is optional on the shared shape and required on the
  // create-only schema below.
  type: z.string().optional(),
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
  auto_capture: false,
}

export const PAYMENT_METHOD_CREATE_DEFAULTS: PaymentMethodFormValues = {
  ...PAYMENT_METHOD_BASE_DEFAULTS,
  type: '',
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
    auto_capture: v.auto_capture,
    storefront_visible: v.storefront_visible,
    ...(Object.keys(preferences).length > 0 ? { preferences } : {}),
  }
}

export function paymentMethodValuesToUpdateParams(
  v: PaymentMethodFormValues,
): PaymentMethodUpdateParams {
  return {
    name: v.name,
    description: v.description?.length ? v.description : null,
    active: v.active,
    auto_capture: v.auto_capture,
    storefront_visible: v.storefront_visible,
  }
}
