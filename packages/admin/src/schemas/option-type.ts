import type { OptionValue, OptionValueParams } from '@spree/admin-sdk'
import { z } from 'zod/v4'
import { i18n } from '@/lib/i18n'
import { requiredMessage } from '@/lib/validation-messages'

// Labels live in `en.json` under `admin.products.options.kinds.*` — consumers
// translate at render time.
export const OPTION_TYPE_KINDS = ['dropdown', 'color_swatch', 'buttons'] as const

const HEX_RE = /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/

export const optionValueSchema = z.object({
  id: z.string().optional(),
  name: z.string().min(1, { error: requiredMessage('name') }),
  label: z.string().min(1, { error: requiredMessage('label') }),
  color_code: z
    .string()
    .nullable()
    .optional()
    .refine((v) => !v || HEX_RE.test(v), {
      error: () => i18n.t('admin.validation.invalid_hex_color'),
    }),
  /** Active Storage signed_id from a fresh direct upload. Frontend-only state. */
  image_signed_id: z.string().nullable().optional(),
  /** Existing image URL (for preview only — never sent back). Frontend-only state. */
  image_url: z.string().nullable().optional(),
  /** True when the user clicks the trash icon next to an existing image. Frontend-only state. */
  image_cleared: z.boolean().optional(),
})

export const optionTypeFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  label: z.string().min(1, { error: requiredMessage('label') }),
  kind: z.enum(OPTION_TYPE_KINDS),
  filterable: z.boolean(),
  option_values: z.array(optionValueSchema),
})

export type OptionTypeFormValues = z.infer<typeof optionTypeFormSchema>
export type OptionValueFormValue = z.infer<typeof optionValueSchema>

export const OPTION_TYPE_DEFAULTS: OptionTypeFormValues = {
  name: '',
  label: '',
  kind: 'dropdown',
  filterable: false,
  option_values: [],
}

/**
 * Hydrate the form from an API option_value row. Spreads all API fields 1:1 and
 * attaches the frontend-only image upload-state fields (`image_signed_id`,
 * `image_cleared`) initialized to their resting values.
 */
export function optionValueToFormRow(ov: OptionValue): OptionValueFormValue {
  return {
    ...ov,
    image_signed_id: null,
    image_cleared: false,
  }
}

/**
 * Build the API payload for a single option_value row. `index` is the row's
 * current array position; we send `position: index + 1` (1-indexed) so
 * `acts_as_list` persists the drag-reordered order. The frontend-only image
 * upload state collapses into the API's `image` field: a fresh signed_id is
 * sent, an explicit clear sends `null`, and an untouched row omits `image`
 * entirely so the existing attachment stays.
 */
export function valueToParam(v: OptionValueFormValue, index: number): OptionValueParams {
  const { image_signed_id, image_url: _imageUrl, image_cleared, ...rest } = v
  return {
    ...rest,
    position: index + 1,
    ...(image_signed_id ? { image: image_signed_id } : image_cleared ? { image: null } : {}),
  }
}
