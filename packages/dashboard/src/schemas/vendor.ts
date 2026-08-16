import type { VendorCreateParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

/**
 * The lifecycle, in the order a vendor normally travels it. `status` is
 * never part of a form: each move is its own workflow on the server, so the
 * list here is only for rendering labels and filters.
 */
export const VENDOR_STATUSES = [
  'pending',
  'invited',
  'onboarding',
  'ready_for_review',
  'approved',
  'suspended',
  'rejected',
  'canceled',
] as const

export type VendorStatus = (typeof VENDOR_STATUSES)[number]

export const TAX_REMITTANCES = ['vendor', 'platform'] as const
export const PAYOUT_INTERVALS = ['daily', 'weekly', 'biweekly', 'monthly', 'manual'] as const

export const vendorFormSchema = z.object({
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

export type VendorFormValues = z.infer<typeof vendorFormSchema>

export const VENDOR_DEFAULTS: VendorFormValues = {
  name: '',
  slug: '',
  contact_email: '',
  billing_email: '',
  about: '',
  tax_remittance: 'vendor',
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

export function vendorValuesToParams(values: VendorFormValues): VendorCreateParams {
  return {
    name: values.name,
    slug: blankToNull(values.slug) ?? undefined,
    contact_email: blankToNull(values.contact_email),
    billing_email: blankToNull(values.billing_email),
    about: blankToNull(values.about),
    tax_remittance: values.tax_remittance,
    payouts_schedule_interval: blankToNull(values.payouts_schedule_interval) as
      | VendorCreateParams['payouts_schedule_interval']
      | null,
    minimum_payout_amount: blankToNull(values.minimum_payout_amount),
    holiday_mode_until: blankToNull(values.holiday_mode_until),
  }
}

/** The image params only, for the sheet that owns the branding. */
export function vendorImageParams(
  values: VendorFormValues,
): Pick<VendorCreateParams, 'logo' | 'square_logo' | 'cover_photo'> {
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

export const vendorInviteSchema = z.object({
  email: z.email({ error: requiredMessage('email') }),
})

export type VendorInviteValues = z.infer<typeof vendorInviteSchema>

/** Suspending and rejecting both take an optional note for the vendor. */
export const vendorReasonSchema = z.object({
  reason: z.string().trim().optional(),
})

export type VendorReasonValues = z.infer<typeof vendorReasonSchema>
