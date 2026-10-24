import { compareMoney, isDecimalString, PAYOUT_SCHEDULE_INTERVALS } from '@spree/core'
import { i18n } from '@spree/dashboard-core'
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
  seller_digital_assets_enabled: z.boolean(),
  // Each entry must be a type/subtype, or a typo would refuse every seller
  // upload.
  seller_digital_asset_content_types: z
    .array(z.string())
    .refine((types) => types.every((type) => isMediaType(type)), {
      message: i18n.t('admin.fields.store.seller_digital_asset_content_types.invalid'),
    }),
  review_seller_digital_asset_changes: z.boolean(),
  send_seller_transactional_emails: z.boolean(),
  // A percentage, because that is how a merchant states a VAT rate. The
  // preference behind it is a fraction bounded at 1, so the field is bounded
  // at 100 and converted on the way in and out (see `percentToFraction`).
  commission_tax_rate_percentage: nonNegativeDecimal.refine(
    (value) => !isDecimalString(value) || compareMoney(value, '100') <= 0,
  ),
})

export type MarketplaceSettingsFormValues = z.infer<typeof marketplaceSettingsFormSchema>

const MEDIA_TYPE = /^[a-z0-9][a-z0-9!#$&^_.+-]*\/[a-z0-9][a-z0-9!#$&^_.+*-]*$/i

/** Whether a typed value has the `type/subtype` shape the store accepts. */
export function isMediaType(value: string): boolean {
  return MEDIA_TYPE.test(value)
}

export const CONTENT_TYPE_FAMILIES = ['audio', 'video', 'image', 'text'] as const
export type ContentTypeFamily = (typeof CONTENT_TYPE_FAMILIES)[number]

/**
 * The formats digital goods usually come in, offered in the picker so an
 * operator does not have to know the content type of a FLAC file. The format
 * name is the label; it is the same in every language, like a currency code.
 * Anything not listed can still be typed in.
 */
export const DIGITAL_FILE_CONTENT_TYPES: ReadonlyArray<{ value: string; format: string }> = [
  { value: 'application/pdf', format: 'PDF' },
  { value: 'application/epub+zip', format: 'EPUB' },
  { value: 'application/zip', format: 'ZIP' },
  { value: 'application/x-7z-compressed', format: '7Z' },
  { value: 'application/gzip', format: 'GZIP' },
  { value: 'application/x-tar', format: 'TAR' },
  { value: 'application/vnd.rar', format: 'RAR' },
  { value: 'application/json', format: 'JSON' },
  { value: 'application/xml', format: 'XML' },
  { value: 'text/plain', format: 'TXT' },
  { value: 'text/csv', format: 'CSV' },
  { value: 'text/markdown', format: 'Markdown' },
  { value: 'application/msword', format: 'DOC' },
  {
    value: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    format: 'DOCX',
  },
  { value: 'application/vnd.ms-excel', format: 'XLS' },
  { value: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', format: 'XLSX' },
  { value: 'application/vnd.ms-powerpoint', format: 'PPT' },
  {
    value: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    format: 'PPTX',
  },
  { value: 'audio/mpeg', format: 'MP3' },
  { value: 'audio/mp4', format: 'M4A' },
  { value: 'audio/aac', format: 'AAC' },
  { value: 'audio/flac', format: 'FLAC' },
  { value: 'audio/ogg', format: 'OGG' },
  { value: 'audio/wav', format: 'WAV' },
  { value: 'audio/x-wav', format: 'WAV' },
  { value: 'audio/aiff', format: 'AIFF' },
  { value: 'audio/midi', format: 'MIDI' },
  { value: 'video/mp4', format: 'MP4' },
  { value: 'video/webm', format: 'WebM' },
  { value: 'video/quicktime', format: 'MOV' },
  { value: 'video/x-matroska', format: 'MKV' },
  { value: 'image/jpeg', format: 'JPEG' },
  { value: 'image/png', format: 'PNG' },
  { value: 'image/gif', format: 'GIF' },
  { value: 'image/webp', format: 'WebP' },
  { value: 'image/tiff', format: 'TIFF' },
  { value: 'image/svg+xml', format: 'SVG' },
  { value: 'image/vnd.adobe.photoshop', format: 'PSD' },
  { value: 'font/ttf', format: 'TTF' },
  { value: 'font/otf', format: 'OTF' },
  { value: 'font/woff', format: 'WOFF' },
  { value: 'font/woff2', format: 'WOFF2' },
  { value: 'application/octet-stream', format: 'BIN' },
]
