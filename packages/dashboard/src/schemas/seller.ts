import type { SellerCreateParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

/**
 * The lifecycle, in the order a seller normally travels it. `status` is
 * never part of a form: each move is its own workflow on the server, so the
 * list here is only for rendering labels and filters.
 */
export const SELLER_STATUSES = [
  'pending',
  'invited',
  'onboarding',
  'ready_for_review',
  'approved',
  'suspended',
  'rejected',
  'canceled',
] as const

export type SellerStatus = (typeof SELLER_STATUSES)[number]

export const TAX_REMITTANCES = ['seller', 'platform'] as const
export const PAYOUT_INTERVALS = ['daily', 'weekly', 'biweekly', 'monthly', 'manual'] as const

export const sellerFormSchema = z.object({
  name: z
    .string()
    .trim()
    .min(1, { error: requiredMessage('name') }),
  slug: z.string().trim().optional(),
  contact_email: z.email().or(z.literal('')).optional(),
  billing_email: z.email().or(z.literal('')).optional(),
  about: z.string().optional(),
  tax_remittance: z.enum(TAX_REMITTANCES).optional(),
  payouts_schedule_interval: z.enum(PAYOUT_INTERVALS).or(z.literal('')).optional(),
  minimum_payout_amount: z.string().trim().optional(),
  holiday_mode_until: z.string().optional(),
  // Three-state image fields, one triple per attachment. See ResourceImageField.
  logo_signed_id: z.string().nullable(),
  logo_preview_url: z.string().nullable(),
  logo_cleared: z.boolean(),
  square_logo_signed_id: z.string().nullable(),
  square_logo_preview_url: z.string().nullable(),
  square_logo_cleared: z.boolean(),
  cover_photo_signed_id: z.string().nullable(),
  cover_photo_preview_url: z.string().nullable(),
  cover_photo_cleared: z.boolean(),
})

export type SellerFormValues = z.infer<typeof sellerFormSchema>

export const SELLER_DEFAULTS: SellerFormValues = {
  name: '',
  slug: '',
  contact_email: '',
  billing_email: '',
  about: '',
  tax_remittance: 'seller',
  payouts_schedule_interval: '',
  minimum_payout_amount: '',
  holiday_mode_until: '',
  logo_signed_id: null,
  logo_preview_url: null,
  logo_cleared: false,
  square_logo_signed_id: null,
  square_logo_preview_url: null,
  square_logo_cleared: false,
  cover_photo_signed_id: null,
  cover_photo_preview_url: null,
  cover_photo_cleared: false,
}

export function sellerValuesToParams(values: SellerFormValues): SellerCreateParams {
  return {
    name: values.name,
    slug: blankToNull(values.slug) ?? undefined,
    contact_email: blankToNull(values.contact_email),
    billing_email: blankToNull(values.billing_email),
    about: blankToNull(values.about),
    tax_remittance: values.tax_remittance,
    payouts_schedule_interval: blankToNull(values.payouts_schedule_interval) as
      | SellerCreateParams['payouts_schedule_interval']
      | null,
    minimum_payout_amount: blankToNull(values.minimum_payout_amount),
    holiday_mode_until: blankToNull(values.holiday_mode_until),
  }
}

/** The image params only, for the sheet that owns the branding. */
export function sellerImageParams(
  values: SellerFormValues,
): Pick<SellerCreateParams, 'logo' | 'square_logo' | 'cover_photo'> {
  return {
    ...imageParam('logo', values.logo_signed_id, values.logo_cleared),
    ...imageParam('square_logo', values.square_logo_signed_id, values.square_logo_cleared),
    ...imageParam('cover_photo', values.cover_photo_signed_id, values.cover_photo_cleared),
  }
}

// Three-state mapping: a fresh upload sends the signed_id, an explicit clear
// sends null (purges the attachment), and an untouched field is omitted.
function imageParam(
  key: 'logo' | 'square_logo' | 'cover_photo',
  signedId: string | null,
  cleared: boolean,
): Partial<Record<'logo' | 'square_logo' | 'cover_photo', string | null>> {
  if (signedId) return { [key]: signedId }
  if (cleared) return { [key]: null }
  return {}
}

export const sellerInviteSchema = z.object({
  email: z.email({ error: requiredMessage('email') }),
})

export type SellerInviteValues = z.infer<typeof sellerInviteSchema>

/** Suspending and rejecting both take an optional note for the seller. */
export const sellerReasonSchema = z.object({
  reason: z.string().trim().optional(),
})

export type SellerReasonValues = z.infer<typeof sellerReasonSchema>
