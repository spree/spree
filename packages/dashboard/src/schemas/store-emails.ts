import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

// Optional email fields use `.or(z.literal(''))` so the form can render an
// empty input without tripping the email validator. The mapper to API params
// converts empty strings to `null` so the backend treats them as cleared.
const optionalEmail = z.string().email().or(z.literal('')).optional()
const optionalColor = z
  .string()
  .regex(/^#[0-9A-Fa-f]{6}$/)
  .or(z.literal(''))
  .nullable()
  .optional()

/** Fonts customer emails can use; mirrors `Spree::Emails::Branding::FONTS`. */
export const EMAIL_FONTS = [
  'inter',
  'system',
  'helvetica',
  'georgia',
  'roboto',
  'lato',
  'merriweather',
] as const

/** Colors customer emails can be branded with, in the order the card shows them. */
export const EMAIL_BRANDING_COLORS = [
  'accent_color',
  'background_color',
  'card_color',
  'text_color',
  'heading_color',
] as const

export const storeEmailsFormSchema = z.object({
  mail_from_address: z
    .string()
    .min(1, { error: requiredMessage('store.mail_from_address') })
    .email(),
  customer_support_email: optionalEmail,
  new_order_notifications_email: optionalEmail,
  send_consumer_transactional_emails: z.boolean(),
  email_accent_color: optionalColor,
  email_background_color: optionalColor,
  email_card_color: optionalColor,
  email_text_color: optionalColor,
  email_heading_color: optionalColor,
  email_font: z.enum(EMAIL_FONTS),

  // Active Storage signed_id from a fresh direct upload. Frontend-only state.
  mailer_logo_signed_id: z.string().nullable().optional(),
  // Local blob URL for the just-picked file so the preview updates before save.
  mailer_logo_preview_url: z.string().nullable().optional(),
  // Tracks the user clicking "Remove logo" — collapses to `mailer_logo: null`.
  mailer_logo_cleared: z.boolean().optional(),
})

export type StoreEmailsFormValues = z.infer<typeof storeEmailsFormSchema>
