import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

// Labels live in `en.json` under `admin.store.unit_systems.*` and
// `admin.store.weight_units.*`. Consumers translate at render time.
export type UnitSystem = 'metric' | 'imperial'
export const UNIT_SYSTEMS: readonly UnitSystem[] = ['metric', 'imperial']
export const WEIGHT_UNITS: Record<UnitSystem, readonly string[]> = {
  metric: ['kg', 'g'],
  imperial: ['lb', 'oz'],
}
const ALL_WEIGHT_UNITS = [...WEIGHT_UNITS.metric, ...WEIGHT_UNITS.imperial] as const

// Store-wide storefront posture. Unlike the channel field there is no blank
// "inherit" option — the store is the terminal fallback in the resolution
// chain, so it always holds a concrete value. Labels live in `en.json` under
// `admin.fields.store.storefront_access.options.*`. `approval_required`:
// anyone browses, but prices come back null and checkout is refused unless
// the customer belongs to an active company.
export const STOREFRONT_ACCESS_LEVELS = [
  'public',
  'prices_hidden',
  'login_required',
  'approval_required',
] as const

/**
 * How document numbers are produced. `sequential` counts up from a starting
 * value; `random` is the pre-6.0 behaviour, opted into by merchants who would
 * rather not disclose order volume. Labels live in `en.json` under
 * `admin.fields.store.document_number_format.options.*`.
 */
export const DOCUMENT_NUMBER_FORMATS = ['sequential', 'random'] as const

// Prefix/suffix accept the characters that read cleanly on an invoice and
// survive a phone call: uppercase letters, digits, dash and hash.
const NUMBER_AFFIX_PATTERN = /^[A-Z0-9#-]*$/

// When customers are charged rather than only authorized. A payment method may
// override this; the store is the terminal fallback, so it always holds a
// concrete value. Labels live in `en.json` under
// `admin.fields.store.capture_method.options.*`.
export const CAPTURE_METHODS = ['checkout', 'on_dispatch', 'manual'] as const
/** What a store does when its pricing or inventory provider cannot answer. */
export const PROVIDER_FAILURE_POLICIES = ['strict', 'fallback'] as const
/** Spree's own catalog and stock records — the default for both providers. */
export const INTERNAL_PROVIDER_KEY = 'internal'

export const storeSettingsFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('store.name') }),
  preferred_admin_locale: z.string().nullable().optional(),
  preferred_timezone: z.string().min(1, { error: requiredMessage('store.preferred_timezone') }),
  preferred_unit_system: z.enum(['metric', 'imperial']),
  preferred_weight_unit: z.enum(ALL_WEIGHT_UNITS),
  preferred_default_package_weight: z.coerce.number().min(0),
  preferred_default_package_length: z.coerce.number().min(0),
  preferred_default_package_width: z.coerce.number().min(0),
  preferred_default_package_height: z.coerce.number().min(0),
  preferred_storefront_access: z.enum(STOREFRONT_ACCESS_LEVELS),
  preferred_guest_checkout: z.boolean(),
  preferred_company_field_enabled: z.boolean(),
  preferred_address_requires_phone: z.boolean(),
  preferred_capture_method: z.enum(CAPTURE_METHODS),
  preferred_pricing_provider: z.string(),
  preferred_inventory_provider: z.string(),
  preferred_pricing_provider_failure_policy: z.enum(PROVIDER_FAILURE_POLICIES),
  preferred_inventory_provider_failure_policy: z.enum(PROVIDER_FAILURE_POLICIES),
  preferred_tax_using_ship_address: z.boolean(),
  preferred_track_inventory_levels: z.boolean(),
  preferred_stock_reservations_enabled: z.boolean(),
  preferred_track_price_history: z.boolean(),
  preferred_show_products_without_price: z.boolean(),
  preferred_disable_sku_validation: z.boolean(),
  preferred_document_number_format: z.enum(DOCUMENT_NUMBER_FORMATS),
  preferred_order_number_prefix: z
    .string()
    .max(10)
    .regex(NUMBER_AFFIX_PATTERN, { error: 'admin.fields.store.order_number_prefix.invalid' }),
  preferred_order_number_suffix: z
    .string()
    .max(10)
    .regex(NUMBER_AFFIX_PATTERN, { error: 'admin.fields.store.order_number_suffix.invalid' }),
  preferred_order_number_sequence_start: z.coerce.number().int().min(1),
  // Store-wide download allowances. Individual files can override the numbers;
  // switching a limit off here removes it for the whole store.
  preferred_limit_digital_download_count: z.boolean(),
  preferred_digital_asset_authorized_clicks: z.coerce
    .number()
    .int()
    .min(1, { error: requiredMessage('store.preferred_digital_asset_authorized_clicks') }),
  preferred_limit_digital_download_days: z.boolean(),
  preferred_digital_asset_authorized_days: z.coerce
    .number()
    .int()
    .min(1, { error: requiredMessage('store.preferred_digital_asset_authorized_days') }),
})

export type StoreSettingsFormValues = z.infer<typeof storeSettingsFormSchema>
