import { z } from 'zod'

/**
 * Why an order is being cancelled, and what happens to the money and the
 * customer.
 *
 * Both toggles are always present in the form; which of them a surface
 * actually renders is its own business — the seller branch accepts no refund
 * argument at all, so it never shows that one.
 */
export const cancelOrderFormSchema = z.object({
  cancel_reason_id: z.string(),
  cancel_note: z.string(),
  refund_payments: z.boolean(),
  notify_customer: z.boolean(),
})

export type CancelOrderFormValues = z.infer<typeof cancelOrderFormSchema>

export const CANCEL_ORDER_DEFAULTS: CancelOrderFormValues = {
  cancel_reason_id: '',
  cancel_note: '',
  // Off by default, like the API: releasing the gateway's hold is automatic,
  // but handing back money already taken is the merchant's call.
  refund_payments: false,
  notify_customer: false,
}
