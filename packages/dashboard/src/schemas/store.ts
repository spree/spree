import {
  CAPTURE_METHODS,
  DOCUMENT_NUMBER_FORMATS,
  PROVIDER_FAILURE_POLICIES,
  STOREFRONT_ACCESSES,
  UNIT_SYSTEMS,
  WeightUnit,
} from '@spree/core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

// Prefix/suffix accept the characters that read cleanly on an invoice and
// survive a phone call: uppercase letters, digits, dash and hash.
const NUMBER_AFFIX_PATTERN = /^[A-Z0-9#-]*$/

/** Spree's own catalog and stock records — the default for both providers. */
export const INTERNAL_PROVIDER_KEY = 'internal'

export const storeSettingsFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('store.name') }),
  seo_title: z.string(),
  meta_description: z.string(),
  // A language the server does not list is refused there, under this field,
  // rather than here, where a stored one would block every other setting.
  admin_locale: z.string().nullable().optional(),
  timezone: z.string().min(1, { error: requiredMessage('store.timezone') }),
  unit_system: z.enum(UNIT_SYSTEMS),
  weight_unit: z.enum(WeightUnit),
  storefront_access: z.enum(STOREFRONT_ACCESSES),
  guest_checkout: z.boolean(),
  always_include_confirm_step: z.boolean(),
  company_field_enabled: z.boolean(),
  address_requires_phone: z.boolean(),
  capture_method: z.enum(CAPTURE_METHODS),
  pricing_provider: z.string(),
  inventory_provider: z.string(),
  pricing_provider_failure_policy: z.enum(PROVIDER_FAILURE_POLICIES),
  inventory_provider_failure_policy: z.enum(PROVIDER_FAILURE_POLICIES),
  tax_using_ship_address: z.boolean(),
  track_inventory_levels: z.boolean(),
  stock_reservations_enabled: z.boolean(),
  low_stock_threshold: z.coerce
    .number()
    .int()
    .min(0, { error: requiredMessage('store.low_stock_threshold') }),
  track_price_history: z.boolean(),
  show_products_without_price: z.boolean(),
  disable_sku_validation: z.boolean(),
  document_number_format: z.enum(DOCUMENT_NUMBER_FORMATS),
  order_number_prefix: z
    .string()
    .max(10)
    .regex(NUMBER_AFFIX_PATTERN, { error: 'admin.fields.store.order_number_prefix.invalid' }),
  order_number_suffix: z
    .string()
    .max(10)
    .regex(NUMBER_AFFIX_PATTERN, { error: 'admin.fields.store.order_number_suffix.invalid' }),
  order_number_sequence_start: z.coerce.number().int().min(1),
  // Store-wide download allowances. Individual files can override the numbers;
  // switching a limit off here removes it for the whole store.
  limit_digital_download_count: z.boolean(),
  digital_asset_authorized_clicks: z.coerce
    .number()
    .int()
    .min(1, { error: requiredMessage('store.digital_asset_authorized_clicks') }),
  limit_digital_download_days: z.boolean(),
  digital_asset_authorized_days: z.coerce
    .number()
    .int()
    .min(1, { error: requiredMessage('store.digital_asset_authorized_days') }),
})

export type StoreSettingsFormValues = z.infer<typeof storeSettingsFormSchema>
