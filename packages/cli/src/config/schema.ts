import { z } from 'zod'

/**
 * The shape of `spree.config.yml`. Sections mirror Admin API resources but
 * are written the way a person writes them: references by natural key, prices
 * keyed by currency, stock keyed by warehouse name, preferences without the
 * `preferred_` prefix.
 */

const nonEmpty = z.string().min(1)
const isoCountry = z.string().regex(/^[A-Z]{2}$/, 'an ISO 3166-1 alpha-2 country code such as US')
const isoCurrency = z.string().regex(/^[A-Z]{3}$/, 'an ISO 4217 currency code such as USD')
const scalar = z.union([z.string(), z.number(), z.boolean(), z.null()])
const preferences = z
  .record(z.string(), scalar)
  .describe('Preferences without the `preferred_` prefix, e.g. `guest_checkout: false`.')
const money = z.number().nonnegative()
const moneyByCurrency = z
  .record(isoCurrency, money)
  .describe('Amount per currency, e.g. `{ USD: 29.99, EUR: 27.9 }`.')
const stockByLocation = z
  .record(nonEmpty, z.number().int().nonnegative())
  .describe('Quantity on hand per stock location name.')

export const storeSchema = z
  .object({
    name: nonEmpty.optional(),
    mail_from_address: z.string().optional(),
    customer_support_email: z.string().optional(),
    new_order_notifications_email: z.string().nullable().optional(),
    preferences: preferences.optional(),
  })
  .strict()
  .describe(
    'The store row seeded at install. Updated only; currency, locale and country are market attributes.',
  )

export const channelSchema = z
  .object({
    code: nonEmpty,
    name: nonEmpty,
    active: z.boolean().optional(),
    default: z.boolean().optional(),
    stock_locations: z.array(nonEmpty).optional().describe('Stock location names.'),
    preferences: preferences.optional(),
  })
  .strict()

export const marketSchema = z
  .object({
    name: nonEmpty,
    currency: isoCurrency,
    countries: z.array(isoCountry).min(1),
    default_locale: z.string().optional(),
    supported_locales: z.array(z.string()).optional(),
    default: z.boolean().optional(),
    tax_inclusive: z.boolean().optional(),
  })
  .strict()

export const customerGroupSchema = z
  .object({
    name: nonEmpty,
    description: z.string().nullable().optional(),
  })
  .strict()

export const taxCategorySchema = z
  .object({
    name: nonEmpty,
    tax_code: z.string().nullable().optional(),
    description: z.string().nullable().optional(),
    default: z.boolean().optional(),
  })
  .strict()

export const deliveryZoneSchema = z
  .object({
    name: nonEmpty,
    description: z.string().nullable().optional(),
    countries: z.array(isoCountry).optional(),
    states: z
      .array(z.object({ country: isoCountry, state: nonEmpty }).strict())
      .optional()
      .describe('State members, as country and state code pairs.'),
  })
  .strict()

export const calculatorSchema = z
  .object({
    type: nonEmpty.describe('Calculator type shorthand, e.g. `flat_rate`.'),
    preferences: z.record(z.string(), scalar).optional(),
  })
  .strict()

export const deliveryMethodSchema = z
  .object({
    name: nonEmpty,
    code: z.string().nullable().optional(),
    admin_name: z.string().nullable().optional(),
    delivery_zone: nonEmpty.optional().describe('Delivery zone name.'),
    calculator: calculatorSchema.optional(),
    storefront_visible: z.boolean().optional(),
    available_to_sellers: z.boolean().optional(),
    tracking_url: z.string().nullable().optional(),
    tax_category: nonEmpty.optional().describe('Tax category name.'),
    pickup_locations: z
      .array(nonEmpty)
      .optional()
      .describe('Stock location names a pickup method offers as collection points.'),
    estimated_transit_business_days_min: z.number().int().positive().nullable().optional(),
    estimated_transit_business_days_max: z.number().int().positive().nullable().optional(),
  })
  .strict()

export const stockLocationSchema = z
  .object({
    name: nonEmpty,
    admin_name: z.string().nullable().optional(),
    active: z.boolean().optional(),
    default: z.boolean().optional(),
    kind: z.string().optional(),
    backorderable_default: z.boolean().optional(),
    propagate_all_variants: z.boolean().optional(),
    pickup_enabled: z.boolean().optional(),
    returns_enabled: z.boolean().optional(),
    address1: z.string().nullable().optional(),
    address2: z.string().nullable().optional(),
    city: z.string().nullable().optional(),
    zipcode: z.string().nullable().optional(),
    country_code: isoCountry.nullable().optional(),
    state_code: z.string().nullable().optional(),
    state_name: z.string().nullable().optional(),
    phone: z.string().nullable().optional(),
    company: z.string().nullable().optional(),
  })
  .strict()

export const supplierSchema = z
  .object({
    name: nonEmpty,
    contact_name: z.string().nullable().optional(),
    email: z.string().nullable().optional(),
    phone: z.string().nullable().optional(),
    notes: z.string().nullable().optional(),
    address1: z.string().nullable().optional(),
    address2: z.string().nullable().optional(),
    city: z.string().nullable().optional(),
    state_name: z.string().nullable().optional(),
    state_code: z.string().nullable().optional(),
    country_code: isoCountry.nullable().optional(),
    postal_code: z.string().nullable().optional(),
  })
  .strict()

export const categorySchema = z
  .object({
    permalink: nonEmpty.describe(
      'Full path, e.g. `clothing/t-shirts`; the parent is the path without its last segment.',
    ),
    name: nonEmpty,
    description: z.string().nullable().optional(),
    meta_title: z.string().nullable().optional(),
    meta_description: z.string().nullable().optional(),
    meta_keywords: z.string().nullable().optional(),
  })
  .strict()

const variantOptions = z
  .record(nonEmpty, nonEmpty)
  .describe('Option type name to option value name, e.g. `{ size: S, color: Red }`.')

export const variantSchema = z
  .object({
    sku: nonEmpty,
    options: variantOptions.optional(),
    prices: moneyByCurrency.optional(),
    compare_at_prices: moneyByCurrency.optional(),
    stock: stockByLocation.optional(),
    barcode: z.string().nullable().optional(),
    weight: z.number().nullable().optional(),
    height: z.number().nullable().optional(),
    width: z.number().nullable().optional(),
    depth: z.number().nullable().optional(),
    track_inventory: z.boolean().optional(),
    cost_price: money.nullable().optional(),
  })
  .strict()

export const productSchema = z
  .object({
    slug: nonEmpty,
    name: nonEmpty,
    status: z.enum(['draft', 'active', 'archived']).optional(),
    description: z.string().nullable().optional(),
    product_type: nonEmpty.optional().describe('Product type name.'),
    tax_category: nonEmpty.optional().describe('Tax category name.'),
    categories: z.array(nonEmpty).optional().describe('Category permalinks.'),
    channels: z.array(nonEmpty).optional().describe('Channel codes the product is published on.'),
    tags: z.array(nonEmpty).optional(),
    meta_title: z.string().nullable().optional(),
    meta_description: z.string().nullable().optional(),
    sku: nonEmpty.optional().describe('SKU of a simple product (one without option variants).'),
    prices: moneyByCurrency.optional().describe('Prices of a simple product.'),
    compare_at_prices: moneyByCurrency.optional(),
    stock: stockByLocation.optional().describe('Stock of a simple product.'),
    variants: z
      .array(variantSchema)
      .optional()
      .describe('Option variants; the whole set, since variants absent here are removed.'),
  })
  .strict()
  .refine((product) => !(product.variants && (product.sku || product.prices || product.stock)), {
    message:
      'a product declares either `variants` or the simple-product `sku`/`prices`/`stock`, not both',
  })

export const customerSchema = z
  .object({
    email: z.string().email(),
    first_name: z.string().nullable().optional(),
    last_name: z.string().nullable().optional(),
    phone: z.string().nullable().optional(),
    password: nonEmpty.optional().describe('Set on create; never read back.'),
    accepts_email_marketing: z.boolean().optional(),
    tags: z.array(nonEmpty).optional(),
    customer_groups: z.array(nonEmpty).optional().describe('Customer group names.'),
  })
  .strict()

export const sellerSchema = z
  .object({
    slug: nonEmpty,
    name: nonEmpty,
    status: z
      .enum(['approved', 'suspended'])
      .optional()
      .describe(
        'Moves the seller through approve or suspend. A seller can be approved once onboarding has started; a freshly created one cannot.',
      ),
    contact_email: z.string().nullable().optional(),
    billing_email: z.string().nullable().optional(),
    legal_name: z.string().nullable().optional(),
    registration_number: z.string().nullable().optional(),
    tax_remittance: z.string().optional(),
  })
  .strict()

export const configSchema = z
  .object({
    version: z.literal(1),
    store: storeSchema.optional(),
    channels: z.array(channelSchema).optional(),
    markets: z.array(marketSchema).optional(),
    customer_groups: z.array(customerGroupSchema).optional(),
    tax_categories: z.array(taxCategorySchema).optional(),
    delivery_zones: z.array(deliveryZoneSchema).optional(),
    delivery_methods: z.array(deliveryMethodSchema).optional(),
    stock_locations: z.array(stockLocationSchema).optional(),
    suppliers: z.array(supplierSchema).optional(),
    categories: z.array(categorySchema).optional(),
    products: z.array(productSchema).optional(),
    customers: z.array(customerSchema).optional(),
    sellers: z.array(sellerSchema).optional(),
  })
  .strict()

export type SpreeConfig = z.infer<typeof configSchema>
export type StoreEntry = z.infer<typeof storeSchema>
export type ChannelEntry = z.infer<typeof channelSchema>
export type MarketEntry = z.infer<typeof marketSchema>
export type CustomerGroupEntry = z.infer<typeof customerGroupSchema>
export type TaxCategoryEntry = z.infer<typeof taxCategorySchema>
export type DeliveryZoneEntry = z.infer<typeof deliveryZoneSchema>
export type DeliveryMethodEntry = z.infer<typeof deliveryMethodSchema>
export type StockLocationEntry = z.infer<typeof stockLocationSchema>
export type SupplierEntry = z.infer<typeof supplierSchema>
export type CategoryEntry = z.infer<typeof categorySchema>
export type VariantEntry = z.infer<typeof variantSchema>
export type ProductEntry = z.infer<typeof productSchema>
export type CustomerEntry = z.infer<typeof customerSchema>
export type SellerEntry = z.infer<typeof sellerSchema>

/** Where editors fetch the schema from; written into every generated file. */
export const SCHEMA_URL = 'https://spreecommerce.org/docs/schemas/spree-config/1.json'

/** The JSON Schema editors validate against — the same definition the CLI validates with. */
export function toJsonSchema(): Record<string, unknown> {
  const schema = z.toJSONSchema(configSchema, { target: 'draft-7', io: 'input' }) as Record<
    string,
    unknown
  >
  return {
    $id: SCHEMA_URL,
    title: 'Spree store configuration',
    description: 'Declarative configuration of a Spree store, deployed with `spree config deploy`.',
    ...schema,
  }
}
