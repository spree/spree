import { compareMoney, isDecimalString, PAYOUT_SCHEDULE_INTERVALS } from '@spree/core'
import { z } from 'zod'

const nonNegativeDecimal = z
  .string()
  .trim()
  .refine((value) => isDecimalString(value) && !value.startsWith('-'))

export const marketplaceSettingsFormSchema = z.object({
  // Blank is the built-in provider: the marketplace keeps the books and
  // settles by hand.
  payout_provider: z.string(),
  default_payouts_schedule_interval: z.enum(PAYOUT_SCHEDULE_INTERVALS),
  // A canonical decimal string from a number input, sent as typed.
  default_minimum_payout_amount: nonNegativeDecimal,
  auto_approve_sellers: z.boolean(),
  auto_approve_seller_products: z.boolean(),
  send_seller_transactional_emails: z.boolean(),
  // A percentage, because that is how a merchant states a VAT rate. The
  // preference behind it is a fraction bounded at 1, so the field is bounded
  // at 100 and converted on the way in and out (see `percentToFraction`).
  commission_tax_rate_percentage: nonNegativeDecimal.refine(
    (value) => !isDecimalString(value) || compareMoney(value, '100') <= 0,
  ),
})

export type MarketplaceSettingsFormValues = z.infer<typeof marketplaceSettingsFormSchema>
