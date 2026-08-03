import { i18n } from '@spree/dashboard-core'
import { z } from 'zod/v4'

/**
 * New-order form schema. The "customer OR email" rule is enforced at the
 * page level rather than in this schema because `customer` lives outside
 * the RHF state (it's a domain object held in `useState` for the resource
 * combobox). See `routes/_authenticated/$storeId/orders/new.tsx` for the
 * combined `canSubmit` check.
 *
 * Per-attribute server validation (line items, customer reachability, etc.)
 * comes back as a 422 and gets routed through `mapSpreeErrorsToForm`.
 */
export const newOrderFormSchema = z.object({
  email: z
    .string()
    .email({ error: () => i18n.t('admin.validation.invalid_email') })
    .or(z.literal('')),
  customer_note: z.string(),
  internal_note: z.string(),
  coupon_code: z.string(),
  // Empty string = "use store default" (resolved server-side via
  // Order#ensure_channel_presence).
  channel_id: z.string(),
})

export type NewOrderFormValues = z.infer<typeof newOrderFormSchema>

export const NEW_ORDER_DEFAULTS: NewOrderFormValues = {
  email: '',
  customer_note: '',
  internal_note: '',
  coupon_code: '',
  channel_id: '',
}

/**
 * Fee kinds offered when adding a manual fee to an order. The backend accepts
 * any string, so this is the curated admin-facing set, not a DB constraint.
 */
export const FEE_KINDS = ['surcharge', 'handling', 'gift_wrap', 'cod', 'payment'] as const

export type FeeKind = (typeof FEE_KINDS)[number]
