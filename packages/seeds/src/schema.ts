import { z } from 'zod'
import { specShape } from './spec.js'

/**
 * The shape of `spree.seeds.yml`. Sections mirror Admin API resources but
 * are written the way a person writes them: references by natural key, prices
 * keyed by currency, stock keyed by warehouse name.
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
// A value is whatever its definition's field type takes; the API checks it.
const customFieldValues = z
  .record(nonEmpty, z.unknown())
  .optional()
  .describe(
    'Custom field values by key, e.g. `{ material: Cotton }`. A key in another namespace is written `namespace.key`. Fields left out are untouched; `null` clears one.',
  )

// --- Attributes each section writes as they are -----------------------------

// Everything the store endpoint accepts but its uploads (logos), which a
// file cannot carry.
export const STORE_ATTRIBUTES = [
  'name',
  'admin_locale',
  'timezone',
  'weight_unit',
  'unit_system',
  'storefront_access',
  'storefront_url',
  'guest_checkout',
  'always_include_confirm_step',
  'company_field_enabled',
  'address_requires_company',
  'address_requires_phone',
  'capture_method',
  'track_inventory_levels',
  'stock_reservations_enabled',
  'low_stock_threshold',
  'tax_using_ship_address',
  'track_price_history',
  'show_products_without_price',
  'disable_sku_validation',
  'order_routing_strategy',
  'pricing_provider',
  'inventory_provider',
  'pricing_provider_failure_policy',
  'inventory_provider_failure_policy',
  'payout_provider',
  'default_payouts_schedule_interval',
  'default_minimum_payout_amount',
  'auto_approve_sellers',
  'auto_approve_seller_products',
  'send_seller_transactional_emails',
  'default_commission_tax_rate',
  'document_number_format',
  'order_number_prefix',
  'order_number_suffix',
  'order_number_sequence_start',
  'limit_digital_download_count',
  'digital_asset_authorized_clicks',
  'limit_digital_download_days',
  'digital_asset_authorized_days',
  'mail_from_address',
  'customer_support_email',
  'new_order_notifications_email',
  'send_consumer_transactional_emails',
  'email_accent_color',
  'email_background_color',
  'email_card_color',
  'email_text_color',
  'email_heading_color',
  'email_font',
] as const
export const CHANNEL_ATTRIBUTES = [
  'code',
  'name',
  'active',
  'default',
  'order_routing_strategy',
  'storefront_access',
  'guest_checkout',
] as const
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
export const TAX_RATE_ATTRIBUTES = ['name', 'rate_percent', 'show_rate_in_label'] as const
export const CUSTOM_FIELD_DEFINITION_ATTRIBUTES = [
  'namespace',
  'key',
  'label',
  'field_type',
  'resource_type',
  'storefront_visible',
  'searchable',
  'sortable',
] as const
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
export const OPTION_TYPE_ATTRIBUTES = ['name', 'label', 'position', 'filterable', 'kind'] as const
export const COLLECTION_ATTRIBUTES = [
  'permalink',
  'name',
  'description',
  'meta_title',
  'meta_description',
  'meta_keywords',
  'automatic',
  'rules_match_policy',
  'sort_order',
] as const
export const PROMOTION_ATTRIBUTES = [
  'name',
  'description',
  'code',
  'path',
  'starts_at',
  'expires_at',
  'usage_limit',
  'match_policy',
  'kind',
] as const
export const COMPANY_ATTRIBUTES = ['name', 'kind', 'po_number_required'] as const
export const PRICE_LIST_ATTRIBUTES = [
  'name',
  'description',
  'match_policy',
  'starts_at',
  'ends_at',
] as const
export const CATALOG_ATTRIBUTES = [
  'name',
  'description',
  'active',
  'minimum_order_quantity',
  'order_multiple',
] as const
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
export const TAX_EXEMPTION_REASON_ATTRIBUTES = ['code', 'name', 'active'] as const
export const COMMISSION_RATE_ATTRIBUTES = [
  'code',
  'position',
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
  })
  .strict()
  .describe(
    'The store row seeded at install, and its settings. Updated only; currency, locale and country are market attributes.',
  )

export const channelSchema = z
  .object({
    ...specShape('channels', CHANNEL_ATTRIBUTES),
    code: nonEmpty,
    name: nonEmpty,
    stock_locations: names('Stock location names.'),
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

export const taxRateSchema = z
  .object({
    ...specShape('tax_rates', TAX_RATE_ATTRIBUTES),
    name: nonEmpty,
    tax_category: nonEmpty.describe('Tax category name.'),
    country: isoCountry
      .nullable()
      .optional()
      .describe('The country the rate taxes; `null` taxes every country.'),
    state: nonEmpty
      .nullable()
      .optional()
      .describe('State abbreviation within that country; `null` taxes the whole country.'),
  })
  .strict()

export const customFieldDefinitionSchema = z
  .object({
    ...specShape('custom_field_definitions', CUSTOM_FIELD_DEFINITION_ATTRIBUTES),
    resource_type: nonEmpty.describe(
      'What the field attaches to, e.g. `product`, `category`, `seller`. Set on create.',
    ),
    key: nonEmpty,
    field_type: nonEmpty.describe('Field type, e.g. `short_text`, `number`. Set on create.'),
  })
  .strict()
  .describe(
    'Matched on resource type, namespace and key together, so changing one of them declares another definition. The field type cannot change once the definition exists.',
  )

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

// A rule or action of some registered kind. Its settings are that kind's own,
// so the API checks them; the file only says which kind and what it holds.
export const ruleSchema = z
  .object({
    type: nonEmpty.describe('Kind shorthand, e.g. `item_total_rule`.'),
    active: z.boolean().optional(),
    preferences: z.record(z.string(), z.unknown()).optional(),
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
    ...specShape('delivery_methods', DELIVERY_METHOD_ATTRIBUTES),
    name: nonEmpty,
    delivery_profile: nonEmpty.optional().describe('Delivery profile name.'),
    delivery_zone: nonEmpty.optional().describe('Delivery zone name.'),
    calculator: calculatorSchema.optional(),
    tax_category: nonEmpty.optional().describe('Tax category name.'),
    pickup_locations: names('Stock location names a pickup method offers as collection points.'),
    rules: z
      .array(ruleSchema)
      .optional()
      .describe('Eligibility rules; the whole set, since rules absent here are removed.'),
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

export const optionValueSchema = z
  .object({
    name: nonEmpty,
    label: nonEmpty.optional(),
    color_code: z.string().nullable().optional().describe('Hex color of a `color_swatch` value.'),
  })
  .strict()

export const optionTypeSchema = z
  .object({
    ...specShape('option_types', OPTION_TYPE_ATTRIBUTES),
    name: nonEmpty,
    label: nonEmpty,
    values: z
      .array(optionValueSchema)
      .optional()
      .describe(
        'Option values in display order; the whole set, since values absent here are removed.',
      ),
  })
  .strict()

export const productTypeSchema = z
  .object({
    ...specShape('product_types', PRODUCT_TYPE_ATTRIBUTES),
    name: nonEmpty,
    delivery_profile: nonEmpty.optional().describe('Delivery profile name.'),
    option_types: names('Option type names given to products created with this type.'),
    categories: names('Category permalinks given to products created with this type.'),
    custom_fields: z
      .array(
        z
          .object({
            key: nonEmpty.describe(
              'Key of a product custom field definition; `namespace.key` outside the default namespace.',
            ),
            required: z.boolean().optional(),
          })
          .strict(),
      )
      .optional()
      .describe('The custom fields the product form shows for this type, in order; the whole set.'),
  })
  .strict()

export const categorySchema = z
  .object({
    ...specShape('categories', CATEGORY_ATTRIBUTES),
    permalink: permalink.describe(
      'Full path, e.g. `clothing/t-shirts`; the parent is the path without its last segment.',
    ),
    name: nonEmpty,
    custom_fields: customFieldValues,
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
    custom_fields: customFieldValues,
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

export const collectionSchema = z
  .object({
    ...specShape('collections', COLLECTION_ATTRIBUTES),
    permalink: slug,
    name: nonEmpty,
    rules: z
      .array(
        z
          .object({
            type: nonEmpty.describe('Rule kind shorthand, e.g. `tag`.'),
            value: z.string().optional(),
            match_policy: z.string().optional(),
          })
          .strict(),
      )
      .optional()
      .describe('Rules of an automatic collection; the whole set.'),
    products: names(
      'Product slugs of a hand-curated collection; the whole set, since products absent here are removed.',
    ),
    custom_fields: customFieldValues,
  })
  .strict()
  .refine((collection) => !(collection.automatic && collection.products), {
    message: 'an automatic collection takes its products from `rules`, not from `products`',
    path: ['products'],
  })

export const promotionActionSchema = ruleSchema
  .extend({
    calculator: calculatorSchema.optional().describe('For adjustment actions.'),
  })
  .strict()

export const promotionSchema = z
  .object({
    ...specShape('promotions', PROMOTION_ATTRIBUTES),
    name: nonEmpty,
    // Codes are saved in lower case and matched ignoring case.
    code: z.string().trim().toLowerCase().nullable().optional(),
    rules: z.array(ruleSchema).optional().describe('Eligibility rules; the whole set.'),
    actions: z
      .array(promotionActionSchema)
      .optional()
      .describe('What the promotion does; the whole set.'),
  })
  .strict()

export const customerSchema = z
  .object({
    ...specShape('customers', CUSTOMER_ATTRIBUTES),
    // Accounts match on email case-insensitively, as sign-in does.
    email: z.string().trim().toLowerCase().email(),
    password: nonEmpty.optional().describe('Set on create; never read back.'),
    customer_groups: names('Customer group names.'),
  })
  .strict()

export const companySchema = z
  .object({
    ...specShape('companies', COMPANY_ATTRIBUTES),
    name: nonEmpty,
    parent: nonEmpty.optional().describe('Name of the company or division this one sits under.'),
    members: z
      .array(z.string().trim().toLowerCase().email())
      .optional()
      .describe(
        'Emails of existing customers who buy for this company. Listed customers are added; members added elsewhere are kept.',
      ),
  })
  .strict()

export const priceListSchema = z
  .object({
    ...specShape('price_lists', PRICE_LIST_ATTRIBUTES),
    name: nonEmpty,
    active: z
      .boolean()
      .optional()
      .describe('Activates or deactivates the list; a new list starts as a draft.'),
    rules: z
      .array(ruleSchema)
      .optional()
      .describe(
        'Who and what the list applies to; the whole set. A rule that lists records takes their natural keys.',
      ),
  })
  .strict()

export const catalogSchema = z
  .object({
    ...specShape('catalogs', CATALOG_ATTRIBUTES),
    name: nonEmpty,
    companies: names('Company names the catalog is assigned to; a company covers its divisions.'),
    customer_groups: names('Customer group names the catalog is assigned to.'),
    products: names('Product slugs in the assortment; the whole set.'),
  })
  .strict()
  .describe(
    '`companies` and `customer_groups` together are the whole audience: set one and the other is cleared unless it is set too.',
  )

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
    custom_fields: customFieldValues,
  })
  .strict()

const reasonSchema = (
  resource: 'return_reasons' | 'claim_reasons' | 'refund_reasons' | 'order_cancellation_reasons',
) => z.object({ ...specShape(resource, REASON_ATTRIBUTES), name: nonEmpty }).strict()

export const returnReasonSchema = reasonSchema('return_reasons')
export const claimReasonSchema = reasonSchema('claim_reasons')
export const refundReasonSchema = reasonSchema('refund_reasons')
export const orderCancellationReasonSchema = reasonSchema('order_cancellation_reasons')

export const taxExemptionReasonSchema = z
  .object({
    ...specShape('tax_exemption_reasons', TAX_EXEMPTION_REASON_ATTRIBUTES),
    code: nonEmpty.describe(
      'What the tax engine receives for certificates holding this reason; saved in capitals.',
    ),
    name: nonEmpty,
  })
  .strict()

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

export const seedsSchema = z
  .object({
    version: z.literal(1),
    store: storeSchema.optional(),
    stock_locations: z.array(stockLocationSchema).optional(),
    channels: z.array(channelSchema).optional(),
    markets: z.array(marketSchema).optional(),
    customer_groups: z.array(customerGroupSchema).optional(),
    tax_categories: z.array(taxCategorySchema).optional(),
    tax_rates: z.array(taxRateSchema).optional(),
    delivery_profiles: z.array(deliveryProfileSchema).optional(),
    delivery_zones: z.array(deliveryZoneSchema).optional(),
    delivery_methods: z.array(deliveryMethodSchema).optional(),
    package_types: z.array(packageTypeSchema).optional(),
    payment_methods: z.array(paymentMethodSchema).optional(),
    suppliers: z.array(supplierSchema).optional(),
    option_types: z.array(optionTypeSchema).optional(),
    custom_field_definitions: z.array(customFieldDefinitionSchema).optional(),
    categories: z.array(categorySchema).optional(),
    product_types: z.array(productTypeSchema).optional(),
    products: z.array(productSchema).optional(),
    collections: z.array(collectionSchema).optional(),
    promotions: z.array(promotionSchema).optional(),
    customers: z.array(customerSchema).optional(),
    companies: z.array(companySchema).optional(),
    price_lists: z.array(priceListSchema).optional(),
    catalogs: z.array(catalogSchema).optional(),
    sellers: z.array(sellerSchema).optional(),
    return_reasons: z.array(returnReasonSchema).optional(),
    claim_reasons: z.array(claimReasonSchema).optional(),
    refund_reasons: z.array(refundReasonSchema).optional(),
    order_cancellation_reasons: z.array(orderCancellationReasonSchema).optional(),
    tax_exemption_reasons: z.array(taxExemptionReasonSchema).optional(),
    commission_rates: z.array(commissionRateSchema).optional(),
    seller_requirements: z.array(sellerRequirementSchema).optional(),
    api_keys: z.array(apiKeySchema).optional(),
    allowed_origins: z.array(allowedOriginSchema).optional(),
  })
  .strict()

export type SpreeSeeds = z.infer<typeof seedsSchema>
export type StoreEntry = z.infer<typeof storeSchema>
export type ChannelEntry = z.infer<typeof channelSchema>
export type MarketEntry = z.infer<typeof marketSchema>
export type CustomerGroupEntry = z.infer<typeof customerGroupSchema>
export type TaxCategoryEntry = z.infer<typeof taxCategorySchema>
export type TaxRateEntry = z.infer<typeof taxRateSchema>
export type CustomFieldDefinitionEntry = z.infer<typeof customFieldDefinitionSchema>
export type DeliveryProfileEntry = z.infer<typeof deliveryProfileSchema>
export type DeliveryZoneEntry = z.infer<typeof deliveryZoneSchema>
export type DeliveryMethodEntry = z.infer<typeof deliveryMethodSchema>
export type PackageTypeEntry = z.infer<typeof packageTypeSchema>
export type PaymentMethodEntry = z.infer<typeof paymentMethodSchema>
export type StockLocationEntry = z.infer<typeof stockLocationSchema>
export type SupplierEntry = z.infer<typeof supplierSchema>
export type OptionTypeEntry = z.infer<typeof optionTypeSchema>
export type RuleEntry = z.infer<typeof ruleSchema>
export type ProductTypeEntry = z.infer<typeof productTypeSchema>
export type CategoryEntry = z.infer<typeof categorySchema>
export type VariantEntry = z.infer<typeof variantSchema>
export type ProductEntry = z.infer<typeof productSchema>
export type CollectionEntry = z.infer<typeof collectionSchema>
export type PromotionEntry = z.infer<typeof promotionSchema>
export type CustomerEntry = z.infer<typeof customerSchema>
export type CompanyEntry = z.infer<typeof companySchema>
export type PriceListEntry = z.infer<typeof priceListSchema>
export type CatalogEntry = z.infer<typeof catalogSchema>
export type SellerEntry = z.infer<typeof sellerSchema>
export type ReasonEntry = z.infer<typeof returnReasonSchema>
export type TaxExemptionReasonEntry = z.infer<typeof taxExemptionReasonSchema>
export type CommissionRateEntry = z.infer<typeof commissionRateSchema>
export type SellerRequirementEntry = z.infer<typeof sellerRequirementSchema>
export type ApiKeyEntry = z.infer<typeof apiKeySchema>
export type AllowedOriginEntry = z.infer<typeof allowedOriginSchema>

/** Where editors fetch the schema from; written into every generated file. */
export const SCHEMA_URL = 'https://spreecommerce.org/docs/schemas/spree-seeds/1.json'

/** The JSON Schema editors validate against — the same definition the CLI validates with. */
export function toJsonSchema(): Record<string, unknown> {
  const schema = z.toJSONSchema(seedsSchema, { target: 'draft-7', io: 'input' }) as Record<
    string,
    unknown
  >
  return {
    $id: SCHEMA_URL,
    title: 'Spree store configuration',
    description: 'Declarative configuration of a Spree store, deployed with `spree seed`.',
    ...schema,
  }
}
