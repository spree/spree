import { z } from 'zod'

/** How often a marketplace settles its sellers, unless one carries its own. */
export const PAYOUT_SCHEDULE_INTERVALS = [
  'daily',
  'weekly',
  'biweekly',
  'monthly',
  'manual',
] as const

export const marketplaceSettingsFormSchema = z.object({
  // Blank is the built-in provider: the marketplace keeps the books and
  // settles by hand.
  preferred_payout_provider: z.string(),
  preferred_default_payouts_schedule_interval: z.enum(PAYOUT_SCHEDULE_INTERVALS),
  // A number, because the preference is a decimal and the API answers with one.
  preferred_default_minimum_payout_amount: z.coerce.number().min(0),
  preferred_auto_approve_sellers: z.boolean(),
  preferred_auto_approve_seller_products: z.boolean(),
  preferred_send_seller_transactional_emails: z.boolean(),
  // A percentage, because that is how a merchant states a VAT rate. The
  // preference behind it is a fraction bounded at 1, so the field is bounded
  // at 100 and converted on the way in and out.
  commission_tax_rate_percentage: z.coerce.number().min(0).max(100),
})

export type MarketplaceSettingsFormValues = z.infer<typeof marketplaceSettingsFormSchema>

/** Rounded because a fraction like 0.077 becomes 7.700000000000001 unrounded. */
export const fractionToPercentage = (fraction: number | string | null | undefined): number =>
  Math.round(Number(fraction ?? 0) * 100 * 1e6) / 1e6

export const percentageToFraction = (percentage: number): number =>
  Math.round((percentage / 100) * 1e8) / 1e8
