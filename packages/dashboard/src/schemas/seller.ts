import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export {
  SELLER_DEFAULTS,
  type SellerFormValues,
  sellerFormSchema,
  sellerFormValues,
  sellerValuesToParams,
} from '@spree/dashboard-core'

export const sellerInviteSchema = z.object({
  email: z.email({ error: requiredMessage('email') }),
})

export type SellerInviteValues = z.infer<typeof sellerInviteSchema>

/** Suspending and rejecting both take an optional note for the seller. */
export const sellerReasonSchema = z.object({
  reason: z.string().trim().optional(),
})

export type SellerReasonValues = z.infer<typeof sellerReasonSchema>
