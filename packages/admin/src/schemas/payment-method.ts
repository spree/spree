import type { PaymentMethodCreateParams, PaymentMethodUpdateParams } from '@spree/admin-sdk'
import { z } from 'zod/v4'
import type { PaymentMethodFormValues } from '@/components/spree/payment-method-editors/types'
import { requiredMessage } from '@/lib/validation-messages'

export const paymentMethodBaseFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  description: z.string().optional(),
  storefront_visible: z.boolean(),
  active: z.boolean(),
  auto_capture: z.boolean(),
})

export const paymentMethodCreateFormSchema = paymentMethodBaseFormSchema.extend({
  type: z.string().min(1, { error: requiredMessage('payment_method.type') }),
})

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
  return {
    type: v.type ?? '',
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
