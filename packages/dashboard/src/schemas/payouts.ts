import { z } from 'zod'

/** How often a marketplace settles its sellers, unless one carries its own. */
export const PAYOUT_SCHEDULE_INTERVALS = [
  'daily',
  'weekly',
  'biweekly',
  'monthly',
  'manual',
] as const

export const payoutSettingsFormSchema = z.object({
  // Blank is the built-in provider: the marketplace keeps the books and
  // settles by hand.
  preferred_payout_provider: z.string(),
  preferred_default_payouts_schedule_interval: z.enum(PAYOUT_SCHEDULE_INTERVALS),
  // A number, because the preference is a decimal and the API answers with one.
  preferred_default_minimum_payout_amount: z.coerce.number().min(0),
})

export type PayoutSettingsFormValues = z.infer<typeof payoutSettingsFormSchema>
