import type { PaymentMethod, PreferenceField } from '@spree/admin-sdk'
import type { UseFormReturn } from 'react-hook-form'
import type { PaymentMethodFormValues } from '../../../schemas/payment-method'

/**
 * Form-state row for a payment method — the in-flight values an editor
 * cares about whether the sheet is in `create` or `edit` mode.
 *
 * Inferred from `paymentMethodBaseFormSchema` so the runtime contract and
 * compile-time type stay in lockstep.
 */
export type { PaymentMethodFormValues }

export type PaymentMethodFormMode = 'create' | 'edit'

/**
 * Slot context for a payment-method-editor slot. Editors mutate
 * `preferences` locally and bubble changes up via `onPreferencesChange`;
 * the parent sheet persists everything on submit. Slots may also use
 * `form` to read/write top-level fields (Active, Display on, …) or
 * register their own fields via `react-hook-form`.
 *
 * Slot keys follow the same per-type pattern as promotion editors:
 *
 *   payment_method.guide.<provider_type>    — banner above the form
 *   payment_method.form.<provider_type>     — replaces preferences form
 *   payment_method.actions.<provider_type>  — footer actions area
 */
export interface PaymentMethodEditorContext {
  mode: PaymentMethodFormMode
  /** The current provider's STI shorthand (`stripe`, `bogus`, …). */
  type: string
  /** Loaded server record in `edit` mode; `null` in `create` mode. */
  paymentMethod: PaymentMethod | null
  preferenceSchema: PreferenceField[]
  preferences: Record<string, unknown>
  onPreferencesChange: (next: Record<string, unknown>) => void
  /** react-hook-form instance for the top-level fields. */
  form: UseFormReturn<PaymentMethodFormValues>
}

const PAYMENT_METHOD_GUIDE_SLOT_PREFIX = 'payment_method.guide.'
const PAYMENT_METHOD_FORM_SLOT_PREFIX = 'payment_method.form.'
const PAYMENT_METHOD_ACTIONS_SLOT_PREFIX = 'payment_method.actions.'

export function paymentMethodGuideSlot(providerType: string): string {
  return `${PAYMENT_METHOD_GUIDE_SLOT_PREFIX}${providerType}`
}

export function paymentMethodFormSlot(providerType: string): string {
  return `${PAYMENT_METHOD_FORM_SLOT_PREFIX}${providerType}`
}

export function paymentMethodActionsSlot(providerType: string): string {
  return `${PAYMENT_METHOD_ACTIONS_SLOT_PREFIX}${providerType}`
}
