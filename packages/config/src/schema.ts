import { z } from 'zod'
import {
  type AttributeOf,
  attributeSchema,
  type Resource,
  specShape,
  writablePreferences,
} from './spec.js'

/**
 * The shape of `spree.config.yml`. Sections mirror Admin API resources but
 * are written the way a person writes them: references by natural key, prices
 * keyed by currency, stock keyed by warehouse name, preferences without the
 * `preferred_` prefix.
 *
 * Plain attributes come from the Admin API spec (`spec.ts`); only what a
 * person writes differently from the API (keys, references, nested shapes) is
 * spelled out here.
 */

const nonEmpty = z.string().min(1)
const isoCountry = z.string().regex(/^[A-Z]{2}$/, 'an ISO 3166-1 alpha-2 country code such as US')
const isoCurrency = z.string().regex(/^[A-Z]{3}$/, 'an ISO 4217 currency code such as USD')
// The API saves slugs and permalinks in a normalized form (lower case,
// hyphenated). A key written any other way would never match its own record,
// so the next deploy would try to create it again; the file must hold the
// saved form.
const slug = z
  .string()
  .regex(
    /^[a-z0-9]+(?:[-_][a-z0-9]+)*$/,
    'lowercase letters and digits joined by single hyphens, e.g. `classic-tee`, the form the API saves',
  )
const permalink = z
  .string()
  .regex(
    /^[a-z0-9]+(?:-[a-z0-9]+)*(?:\/[a-z0-9]+(?:-[a-z0-9]+)*)*$/,
    'lowercase segments joined by hyphens and slashes, e.g. `clothing/t-shirts`, the form the API saves',
  )
const scalar = z.union([z.string(), z.number(), z.boolean(), z.null()])
const money = z.number().nonnegative()
const moneyByCurrency = z
  .record(isoCurrency, money)
  .describe('Amount per currency, e.g. `{ USD: 29.99, EUR: 27.9 }`.')
const stockByLocation = z
  .record(nonEmpty, z.number().int().nonnegative())
  .describe(
    'Opening stock per stock location name, written when the variant is created and never compared again.',
  )
const names = (description: string) => z.array(nonEmpty).optional().describe(description)

/**
 * The preferences a resource permits, typed from the spec and without the
 * `preferred_` prefix. Rails drops any other key without a word, so an
 * unlisted key would read as a change on every deploy; the file refuses it.
 */
function preferencesOf(resource: Resource) {
  return z
    .object(
      Object.fromEntries(
        writablePreferences(resource).map((key) => [
          key,
          attributeSchema(resource, `preferred_${key}` as AttributeOf<typeof resource>).optional(),
        ]),
      ),
    )
    .strict()
    .describe('Preferences without the `preferred_` prefix, e.g. `guest_checkout: false`.')
}

// --- Attributes each section writes as they are -----------------------------

export const STORE_ATTRIBUTES = [
  'name',
  'mail_from_address',
  'customer_support_email',
  'new_order_notifications_email',
] as const
export const CHANNEL_ATTRIBUTES = ['code', 'name', 'active', 'default'] as const
export const MARKET_ATTRIBUTES = [
  'name',
  'currency',
  'default_locale',
  'supported_locales',
  'default',
  'tax_inclusive',
] as const
export const CUSTOMER_GROUP_ATTRIBUTES = ['name', 'description'] as const
export const TAX_CATEGORY_ATTRIBUTES = ['name', 'tax_code', 'description'] as const
export const DELIVERY_PROFILE_ATTRIBUTES = ['name', 'kind', 'default'] as const
export const DELIVERY_ZONE_ATTRIBUTES = ['name', 'description'] as const
export const DELIVERY_METHOD_ATTRIBUTES = [
  'name',
  'code',
  'admin_name',
  'fulfillment_provider',
  'storefront_visible',
  'available_to_sellers',
  'tracking_url',
  'estimated_transit_business_days_min',
  'estimated_transit_business_days_max',
] as const
export const PACKAGE_TYPE_ATTRIBUTES = [
  'name',
  'kind',
  'length',
  'width',
  'height',
  'dimensions_unit',
  'weight',
  'max_weight',
  'weight_unit',
  'default',
] as const
export const PAYMENT_METHOD_ATTRIBUTES = [
  'name',
  'description',
  'active',
  'storefront_visible',
  'capture_method',
  'position',
] as const
export const STOCK_LOCATION_ATTRIBUTES = [
  'name',
  'admin_name',
  'active',
  'default',
  'kind',
  'backorderable_default',
  'propagate_all_variants',
  'pickup_enabled',
  'returns_enabled',
  'address1',
  'address2',
  'city',
  'zipcode',
  'country_code',
  'state_code',
  'state_name',
  'phone',
  'company',
] as const
export const SUPPLIER_ATTRIBUTES = [
  'name',
  'contact_name',
  'email',
  'phone',
  'notes',
  'address1',
  'address2',
  'city',
  'state_name',
  'state_code',
  'country_code',
  'postal_code',
] as const
export const PRODUCT_TYPE_ATTRIBUTES = ['name'] as const
export const CATEGORY_ATTRIBUTES = [
  'permalink',
  'name',
  'description',
  'meta_title',
  'meta_description',
  'meta_keywords',
] as const
export const PRODUCT_ATTRIBUTES = [
  'slug',
  'name',
  'status',
  'description',
  'tags',
  'meta_title',
  'meta_description',
] as const
export const CUSTOMER_ATTRIBUTES = [
  'email',
  'first_name',
  'last_name',
  'phone',
  'accepts_email_marketing',
  'tags',
] as const
export const SELLER_ATTRIBUTES = [
  'slug',
  'name',
  'contact_email',
  'billing_email',
  'legal_name',
  'registration_number',
  'tax_remittance',
] as const
export const REASON_ATTRIBUTES = ['name', 'active'] as const
export const COMMISSION_RATE_ATTRIBUTES = [
  'code',
  'name',
  'enabled',
  'kind',
  'value',
  'tax_inclusive',
  'include_shipping',
  'commission_tax_rate',
] as const
export const SELLER_REQUIREMENT_ATTRIBUTES = [
  'type',
  'name',
  'description',
  'required',
  'active',
  'position',
] as const
export const API_KEY_ATTRIBUTES = ['name', 'key_type', 'scopes'] as const
export const ALLOWED_ORIGIN_ATTRIBUTES = ['origin'] as const

// --- Sections ----------------------------------------------------------------

export const storeSchema = z
  .object({
    ...specShape('store', STORE_ATTRIBUTES),
    name: nonEmpty.optional(),
    preferences: preferencesOf('store').optional(),
  })
  .strict()
  .describe(
    'The store row seeded at install. Updated only; currency, locale and country are market attributes.',
  )

export const channelSchema = z
  .object({
    ...specShape('channels', CHANNEL_ATTRIBUTES),
    code: nonEmpty,
    name: nonEmpty,
    stock_locations: names('Stock location names.'),
    preferences: preferencesOf('channels').optional(),
  })
  .strict()

export const marketSchema = z
  .object({
    ...specShape('markets', MARKET_ATTRIBUTES),
    name: nonEmpty,
    currency: isoCurrency,
    countries: z.array(isoCountry).min(1),
  })
  .strict()

export const customerGroupSchema = z
  .object({ ...specShape('customer_groups', CUSTOMER_GROUP_ATTRIBUTES), name: nonEmpty })
  .strict()

export const taxCategorySchema = z
  .object({
    ...specShape('tax_categories', TAX_CATEGORY_ATTRIBUTES),
    name: nonEmpty,
    default: z.boolean().optional().describe('Marks the store default tax category.'),
  })
  .strict()

export const deliveryProfileSchema = z
  .object({
    ...specShape('delivery_profiles', DELIVERY_PROFILE_ATTRIBUTES),
    name: nonEmpty,
  })
  .strict()
  .describe('`kind` is set when the profile is created and cannot change afterwards.')

export const deliveryZoneSchema = z
  .object({
    ...specShape('delivery_zones', DELIVERY_ZONE_ATTRIBUTES),
    name: nonEmpty,
    delivery_profile: nonEmpty.optional().describe('Delivery profile name.'),
    countries: z.array(isoCountry).optional(),
    all_countries_except: z
      .array(isoCountry)
      .optional()
      .describe('Every country the store knows except these, e.g. an "everywhere else" zone.'),
    states: z
      .array(z.object({ country: isoCountry, state: nonEmpty }).strict())
      .optional()
      .describe('State members, as country and state code pairs.'),
  })
  .strict()
  .refine((zone) => !(zone.countries && zone.all_countries_except), {
    message: 'a zone lists either `countries` or `all_countries_except`, not both',
  })

export const calculatorSchema = z
  .object({
    type: nonEmpty.describe('Calculator type shorthand, e.g. `flat_rate`.'),
    preferences: z.record(z.string(), scalar).optional(),
  })
  .strict()

export const deliveryMethodSchema = z
  .object({
    ...specShape('delivery_methods', DELIVERY_METHOD_ATTRIBUTES),
    name: nonEmpty,
    delivery_profile: nonEmpty.optional().describe('Delivery profile name.'),
    delivery_zone: nonEmpty.optional().describe('Delivery zone name.'),
    calculator: calculatorSchema.optional(),
    tax_category: nonEmpty.optional().describe('Tax category name.'),
    pickup_locations: names('Stock location names a pickup method offers as collection points.'),
  })
  .strict()

export const packageTypeSchema = z
  .object({ ...specShape('package_types', PACKAGE_TYPE_ATTRIBUTES), name: nonEmpty })
  .strict()

export const paymentMethodSchema = z
  .object({
    ...specShape('payment_methods', PAYMENT_METHOD_ATTRIBUTES),
    name: nonEmpty,
    type: nonEmpty.describe('Payment method type shorthand, e.g. `store_credit`. Set on create.'),
  })
  .strict()

export const stockLocationSchema = z
  .object({
    ...specShape('stock_locations', STOCK_LOCATION_ATTRIBUTES),
    name: nonEmpty,
    country_code: isoCountry.nullable().optional(),
  })
  .strict()

export const supplierSchema = z
  .object({
    ...specShape('suppliers', SUPPLIER_ATTRIBUTES),
    name: nonEmpty,
    country_code: isoCountry.nullable().optional(),
  })
  .strict()

export const productTypeSchema = z
  .object({
    ...specShape('product_types', PRODUCT_TYPE_ATTRIBUTES),
    name: nonEmpty,
    delivery_profile: nonEmpty.optional().describe('Delivery profile name.'),
  })
  .strict()

export const categorySchema = z
  .object({
    ...specShape('categories', CATEGORY_ATTRIBUTES),
    permalink: permalink.describe(
      'Full path, e.g. `clothing/t-shirts`; the parent is the path without its last segment.',
    ),
    name: nonEmpty,
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
    ...specShape('products', PRODUCT_ATTRIBUTES),
    slug,
    name: nonEmpty,
    product_type: nonEmpty.optional().describe('Product type name.'),
    tax_category: nonEmpty.optional().describe('Tax category name.'),
    categories: names('Category permalinks.'),
    channels: names('Channel codes the product is published on.'),
    sku: nonEmpty.optional().describe('SKU of a simple product (one without option variants).'),
    prices: moneyByCurrency.optional().describe('Prices of a simple product.'),
    compare_at_prices: moneyByCurrency.optional(),
    stock: stockByLocation.optional(),
    variants: z
      .array(variantSchema)
      .optional()
      .describe('Option variants; the whole set, since variants absent here are removed.'),
  })
  .strict()
  .refine(
    (product) =>
      !(
        product.variants &&
        (product.sku || product.prices || product.compare_at_prices || product.stock)
      ),
    {
      message:
        'a product declares either `variants` or the simple-product `sku`/`prices`/`stock`, not both',
    },
  )
  // The variant is matched on its SKU; without one there is nothing to match,
  // and an invented SKU would rename the live one.
  .refine(
    (product) => product.sku || !(product.prices || product.compare_at_prices || product.stock),
    { message: 'a simple product that sets prices or stock needs its `sku`', path: ['sku'] },
  )

export const customerSchema = z
  .object({
    ...specShape('customers', CUSTOMER_ATTRIBUTES),
    // Accounts match on email case-insensitively, as sign-in does.
    email: z.string().trim().toLowerCase().email(),
    password: nonEmpty.optional().describe('Set on create; never read back.'),
    customer_groups: names('Customer group names.'),
  })
  .strict()

export const sellerSchema = z
  .object({
    ...specShape('sellers', SELLER_ATTRIBUTES),
    slug,
    name: nonEmpty,
    status: z
      .enum(['approved', 'suspended'])
      .optional()
      .describe(
        'Moves the seller through approve or suspend. A seller can be approved once onboarding has started; a freshly created one cannot.',
      ),
  })
  .strict()

const reasonSchema = (
  resource: 'return_reasons' | 'claim_reasons' | 'refund_reasons' | 'order_cancellation_reasons',
) => z.object({ ...specShape(resource, REASON_ATTRIBUTES), name: nonEmpty }).strict()

export const returnReasonSchema = reasonSchema('return_reasons')
export const claimReasonSchema = reasonSchema('claim_reasons')
export const refundReasonSchema = reasonSchema('refund_reasons')
export const orderCancellationReasonSchema = reasonSchema('order_cancellation_reasons')

export const commissionRateSchema = z
  .object({ ...specShape('commission_rates', COMMISSION_RATE_ATTRIBUTES), code: nonEmpty })
  .strict()

export const sellerRequirementSchema = z
  .object({
    ...specShape('seller_requirements', SELLER_REQUIREMENT_ATTRIBUTES),
    type: nonEmpty.describe('Requirement type shorthand, e.g. `accept_terms`.'),
    preferences: z.record(z.string(), scalar).optional(),
  })
  .strict()

export const apiKeySchema = z
  .object({
    ...specShape('api_keys', API_KEY_ATTRIBUTES),
    name: nonEmpty,
    key_type: z.enum(['publishable', 'secret']),
    channel: nonEmpty.optional().describe('Channel code a publishable key is bound to.'),
  })
  .strict()
  .describe('Created once and never updated; the token is never written to the file.')

export const allowedOriginSchema = z
  .object({ ...specShape('allowed_origins', ALLOWED_ORIGIN_ATTRIBUTES), origin: nonEmpty })
  .strict()

export const configSchema = z
  .object({
    version: z.literal(1),
    store: storeSchema.optional(),
    stock_locations: z.array(stockLocationSchema).optional(),
    channels: z.array(channelSchema).optional(),
    markets: z.array(marketSchema).optional(),
    customer_groups: z.array(customerGroupSchema).optional(),
    tax_categories: z.array(taxCategorySchema).optional(),
    delivery_profiles: z.array(deliveryProfileSchema).optional(),
    delivery_zones: z.array(deliveryZoneSchema).optional(),
    delivery_methods: z.array(deliveryMethodSchema).optional(),
    package_types: z.array(packageTypeSchema).optional(),
    payment_methods: z.array(paymentMethodSchema).optional(),
    suppliers: z.array(supplierSchema).optional(),
    product_types: z.array(productTypeSchema).optional(),
    categories: z.array(categorySchema).optional(),
    products: z.array(productSchema).optional(),
    customers: z.array(customerSchema).optional(),
    sellers: z.array(sellerSchema).optional(),
    return_reasons: z.array(returnReasonSchema).optional(),
    claim_reasons: z.array(claimReasonSchema).optional(),
    refund_reasons: z.array(refundReasonSchema).optional(),
    order_cancellation_reasons: z.array(orderCancellationReasonSchema).optional(),
    commission_rates: z.array(commissionRateSchema).optional(),
    seller_requirements: z.array(sellerRequirementSchema).optional(),
    api_keys: z.array(apiKeySchema).optional(),
    allowed_origins: z.array(allowedOriginSchema).optional(),
  })
  .strict()

export type SpreeConfig = z.infer<typeof configSchema>
export type StoreEntry = z.infer<typeof storeSchema>
export type ChannelEntry = z.infer<typeof channelSchema>
export type MarketEntry = z.infer<typeof marketSchema>
export type CustomerGroupEntry = z.infer<typeof customerGroupSchema>
export type TaxCategoryEntry = z.infer<typeof taxCategorySchema>
export type DeliveryProfileEntry = z.infer<typeof deliveryProfileSchema>
export type DeliveryZoneEntry = z.infer<typeof deliveryZoneSchema>
export type DeliveryMethodEntry = z.infer<typeof deliveryMethodSchema>
export type PackageTypeEntry = z.infer<typeof packageTypeSchema>
export type PaymentMethodEntry = z.infer<typeof paymentMethodSchema>
export type StockLocationEntry = z.infer<typeof stockLocationSchema>
export type SupplierEntry = z.infer<typeof supplierSchema>
export type ProductTypeEntry = z.infer<typeof productTypeSchema>
export type CategoryEntry = z.infer<typeof categorySchema>
export type VariantEntry = z.infer<typeof variantSchema>
export type ProductEntry = z.infer<typeof productSchema>
export type CustomerEntry = z.infer<typeof customerSchema>
export type SellerEntry = z.infer<typeof sellerSchema>
export type ReasonEntry = z.infer<typeof returnReasonSchema>
export type CommissionRateEntry = z.infer<typeof commissionRateSchema>
export type SellerRequirementEntry = z.infer<typeof sellerRequirementSchema>
export type ApiKeyEntry = z.infer<typeof apiKeySchema>
export type AllowedOriginEntry = z.infer<typeof allowedOriginSchema>

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
