// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type EmailTemplatePreviewParams = {
  /** A language code, or `any` (the default) for the version every language uses. */
  language?: string
  /** An unsaved subject, in place of the current one. */
  subject?: string | null
  /** An unsaved body, in place of the current one. */
  body?: string
  /** The record to build sample data from; the store's latest matching record otherwise. */
  record_id?: string
  /** For the layout or a partial, the email to show it in. */
  email_key?: string
  /** Unsaved colors and font to preview, named like the store's `email_*` settings. */
  branding?: {
    accent_color?: string | null
    background_color?: string | null
    card_color?: string | null
    text_color?: string | null
    heading_color?: string | null
    font?: 'inter' | 'system' | 'helvetica' | 'georgia' | 'roboto' | 'lato' | 'merriweather' | null
  }
  /** An unsaved email logo: the signed id of an uploaded image, or null to preview without one. */
  mailer_logo_signed_id?: string | null
}
