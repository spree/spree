// Request parameter types for Admin API endpoints
// Based on the Admin API OpenAPI specification

import type { PaginationMeta, PreferenceSchema } from '@spree/sdk-core'
import type {
  CountryCode,
  CurrencyCode,
  LocaleCode,
  SellerRequirementStatus,
  StoreCredit,
} from './types'
import type {
  CollectionRuleParams,
  CommissionRuleDraftParams,
  ImportCompleteMappingParams,
  PriceBulkUpsertRowParams,
  PriceListRuleParams,
  PriceParams,
  ProductMediaParams,
  ProductPublicationParams,
  ProductVariantParams,
  PromotionActionDraftParams,
  PromotionRuleDraftParams,
  ShippingLabelCreateParams,
  StockLevelBulkUpsertRowParams,
  StockLevelParams,
  VariantOptionParams,
} from './types/params'

export type * from './types/params'

/** One pricing or inventory engine a store can choose between. */
export interface StoreDataSourceProvider {
  /** What the store preference stores, and what a priced line records as its source. */
  key: string
  name: string
  /** The integration's wire shorthand, for deep-linking to its settings page. */
  integration_type: string | null
  /** False while the provider's integration is not connected for this store. */
  available: boolean
}

/**
 * How sellers get paid. A different shape from the pricing and inventory
 * providers: a payout provider is chosen directly rather than through an
 * integration, and what matters at selection time is whether it will need
 * sellers to hold an account with it.
 */
export interface StorePayoutProvider {
  /** The provider's shorthand (`system`, `stripe`) — what `payout_provider` takes. */
  id: string
  name: string
  /** False when the store has not connected what this provider needs. */
  available: boolean
  /** True when sellers must onboard with the provider before it will pay them. */
  requires_payout_account: boolean
  /** True for the provider used when the store has named none. */
  default: boolean
}

export interface StoreDataSources {
  pricing_providers: StoreDataSourceProvider[]
  inventory_providers: StoreDataSourceProvider[]
  failure_policies: string[]
}

/** One entry from `trackingCarriers.list()`. */
export interface TrackingCarrierOption {
  /** Registry slug — what `tracking_carrier` stores */
  id: string
  /** Carrier display name */
  name: string
}

/** @deprecated Renamed to `ShippingLabelCreateParams`. */
export type ShippingLabelUploadParams = ShippingLabelCreateParams

/** @deprecated Renamed to `ShippingLabelCreateParams`. */
export type ShippingLabelPurchaseParams = ShippingLabelCreateParams

export type MediaType = 'image' | 'video' | 'external_video'

/** Where one library file is in use. */
export interface MediaUsageReference {
  /**
   * `media` — placed on a product or variant; `attachment` — picked for a
   * plain image field such as a category or store logo; `rich_text` — embedded
   * in a description. Rich text matches are best-effort: an embed is a plain
   * URL, so nothing records it.
   */
  kind: 'media' | 'attachment' | 'rich_text'
  name: string | null
  /** Shorthand of the record using the file, e.g. `product`, `variant`, `category`, `collection`. */
  owner_type: string
  owner_id: string | null
  field: string | null
}

/** @deprecated Renamed to `ProductMediaParams`. */
export type ProductMediaInput = ProductMediaParams

/** One per-asset configuration field a provider declares. */
export interface DigitalAssetProviderSettingField {
  key: string
  type: 'string' | 'number' | 'boolean' | 'select'
  default?: unknown
  /** Allowed values for a `select` field. */
  in?: string[]
}

/** A selectable digital-asset source, from the `providers` discovery endpoint. */
export interface DigitalAssetProvider {
  /** Shorthand to send as `provider_type`, e.g. `file`. */
  type: string
  /** Human-readable label. */
  name: string
  /** Whether picking this source requires uploading a file. */
  requires_attachment: boolean
  /** Per-asset fields to render as a form when this source is picked. */
  settings_schema: DigitalAssetProviderSettingField[]
}

/** @deprecated Renamed to `ProductPublicationParams`. */
export type ProductPublicationInput = ProductPublicationParams

/** @deprecated Renamed to `ProductVariantParams`. */
export type ProductVariantInput = ProductVariantParams

/**
 * Default product sort applied to a collection's storefront listing. A
 * shopper's own `sort` param always wins over this; `manual` means the
 * merchant's hand-set product order.
 */
export type CollectionSortOrder =
  | 'manual'
  | 'best_selling'
  | 'price asc'
  | 'price desc'
  | 'available_on desc'
  | 'available_on asc'
  | 'name asc'
  | 'name desc'

/**
 * Wire shorthand (`api_type`) for an automatic-collection rule — what
 * `collectionRules.types()` returns. Ruby class names are not accepted.
 */
export type CollectionRuleType = 'tag' | 'sale' | 'available_on' | (string & {})

export type CollectionRuleMatchPolicy =
  | 'is_equal_to'
  | 'is_not_equal_to'
  | 'contains'
  | 'does_not_contain'

/** @deprecated Renamed to `CollectionRuleParams`. */
export type CollectionRuleParam = CollectionRuleParams

/** @deprecated Renamed to `VariantOptionParams`. */
export type VariantOptionPair = VariantOptionParams

/** @deprecated Renamed to `PriceParams`. */
export type VariantPrice = PriceParams

/** @deprecated Renamed to `StockLevelParams`. */
export type VariantStockLevel = StockLevelParams

/** Response of the public first-run setup availability check. */
export interface SetupStatus {
  /** True only while the installation has no admin user. */
  setup_required: boolean
}

/** A country the store can be set up in, with everything derived from it. */
export interface SetupCountry {
  /** ISO 3166-1 alpha-2 code, e.g. `CH`. */
  code: CountryCode
  /** ISO 4217 currency the store gets when this country is chosen, e.g. `CHF`. */
  currency: CurrencyCode | null
  /** Official languages, e.g. `['de', 'fr', 'it', 'rm']`. */
  locales: LocaleCode[]
}

/** Response of the public first-run setup country list. */
export interface SetupCountries {
  countries: SetupCountry[]
}

/** @deprecated Renamed to `StockLevelBulkUpsertRowParams`. */
export type StockLevelBulkUpsertRow = StockLevelBulkUpsertRowParams

/** Result of enqueueing a backfill of a type's associations onto its products. */
export interface ProductTypeApplyToProductsResponse {
  products_count: number
}

/** A resource a custom field definition can be attached to. */
export interface CustomFieldResourceType {
  /** The value to send as `resource_type`, e.g. `seller`. */
  resource_type: string
  /** What a merchant calls it, e.g. "Sellers". */
  name: string
}

/** A requirement kind an operator can add, and the shape of its form. */
export interface SellerRequirementType {
  type: string
  name: string
  description: string
  allow_multiple: boolean
  accepts_submissions: boolean
  reviewed_by_operator: boolean
  /** Whether this store already has one — single-instance kinds only. */
  configured: boolean
  /** Whether the operator may add one now; the server owns the rule. */
  addable: boolean
  /** What a seller may upload, for kinds that collect a file. */
  accepted_content_types: string[]
  /** Association-backed config this kind takes beyond its preferences. */
  association_fields: string[]
  /** JSON Schema of the kind's `preferences`. */
  schema: PreferenceSchema
}

/** Excusing one seller from one requirement. */
export interface SellerRequirementWaiveParams {
  requirement_id: string
  review_note?: string
}

/** Accepting or rejecting what a seller submitted. */
export interface SellerRequirementReviewParams {
  review_note?: string
}

/** A seller's evaluated onboarding checklist. */
export interface SellerOnboarding {
  status: string
  progress: { done: number; total: number; percentage: number }
  requirements: SellerRequirementStatus[]
}

/** @deprecated Renamed to `CommissionRuleDraftParams`. */
export type CommissionRuleDraft = CommissionRuleDraftParams

/**
 * Mask token the server applies to `:password`-typed preferences before
 * returning them. The value `••••` followed by the original secret's
 * last four characters — Stripe's "stored, last 4 shown" pattern.
 *
 * Mirrors `Spree::Preferences::Masking::TOKEN` on the backend. The
 * backend's write-side guard skips updating a `:password` preference
 * whose submitted value starts with this token, so clients can
 * round-trip a fetched payload without overwriting the real secret.
 */
export const PREFERENCE_MASK_TOKEN = '••••'

/**
 * @param value Anything that might be a masked secret returned from the API.
 * @returns true when the value carries the leading mask token.
 */
export function isMaskedSecret(value: unknown): value is string {
  return typeof value === 'string' && value.startsWith(PREFERENCE_MASK_TOKEN)
}

/**
 * The shape returned by `/<resource>/types` endpoints — one entry per
 * registered subclass with the JSON Schema of its preferences. Used to build "Add
 * provider / action / rule" pickers and render generic preferences forms.
 */
/**
 * One rule kind a commission rate can be narrowed by, as the marketplace
 * reports it. `schema` describes the configuration the kind takes,
 * and `association_fields` names any catalog-scale reference it keeps outside
 * that — so a client can render the right editor without knowing the kind.
 */
export interface CommissionRuleType {
  type: string
  name: string
  description: string | null
  /** JSON Schema of the type's `preferences`. */
  schema: PreferenceSchema
  association_fields: string[]
}

export interface ResourceTypeDefinition {
  type: string
  label: string
  description: string | null
  /** JSON Schema of the type's `preferences`. */
  schema: PreferenceSchema
  /**
   * Present (true) only on kinds a better mechanism has replaced: existing
   * records keep working and rendering, but pickers must stop offering the
   * kind to new setups.
   */
  superseded?: boolean
}

// ---------------------------------------------------------------------------
// Price Lists
// ---------------------------------------------------------------------------

/** @deprecated Renamed to `PriceListRuleParams`. */
export type PriceListRuleDraft = PriceListRuleParams

// ---------------------------------------------------------------------------
// Prices (generic — base prices AND price-list overrides)
// ---------------------------------------------------------------------------

/** @deprecated Renamed to `PriceBulkUpsertRowParams`. */
export type PriceBulkUpsertRow = PriceBulkUpsertRowParams

/**
 * One entry returned by `GET /payment_methods/types` — the registered list
 * of available STI subclasses, with their per-provider preference schemas
 * for the universal configuration form and their gallery listing.
 */
export interface PaymentMethodType extends ResourceTypeDefinition {
  /** Gallery logo: an absolute URL to hosted brand assets, or a `data:` URI. Render with a fallback. */
  logo_url: string | null
  /** Absolute URL of the provider's setup guide. */
  docs_url: string | null
  /** Backed by an external payment provider rather than handled by the store itself. */
  third_party: boolean
  /** The store already has a payment method of this type; leave it out of a create picker. */
  installed: boolean
}

/**
 * One entry returned by `GET /integrations/types` — every registered
 * integration with its gallery metadata and configuration schema. Pure
 * registry discovery: read live connection state from `integrations.list()`.
 */
export interface IntegrationTypeDefinition {
  /** Wire shorthand (`Spree::Integration.api_type`), not the Ruby class name. */
  type: string
  name: string
  /** Display grouping, e.g. `shipping`, `tax`; null for ungrouped. */
  group: string | null
  /**
   * One-line description in the request locale. A fallback: the dashboard
   * prefers its own translation of `type` and reads this only when it has
   * none, which is the case for provider gems shipping no dashboard locales.
   */
  description: string | null
  /** Gallery logo: an absolute URL to hosted brand assets, or a `data:` URI for self-contained gems. Render with a fallback — hosted logos are a courtesy, not a guarantee. */
  logo_url: string | null
  /** Absolute URL of the integration's setup guide. */
  docs_url: string | null
  /** JSON Schema of the type's `preferences`. */
  schema: PreferenceSchema
}

/**
 * API shorthand for an export type (`Spree::Export.api_type`), not the Ruby
 * class name. The server validates `type` against the configured allowlist
 * (`Spree::Export.available_types`); a plugin can register additional types,
 * which arrive here as the trailing `string & {}` arm.
 * List filters (`type_eq`) take the same shorthand.
 */
export type ExportType =
  | 'products'
  | 'orders'
  | 'customers'
  | 'product_translations'
  | 'gift_cards'
  | 'coupon_codes'
  | 'newsletter_subscribers'
  | 'price_list_prices'
  | (string & {})

/**
 * API shorthand for an import type (`Spree::Import.api_type`), not the Ruby
 * class name.
 */
export type ImportType =
  | 'products'
  | 'customers'
  | 'product_translations'
  | 'price_list_prices'
  | (string & {})

/** @deprecated Use `ImportCompleteMappingParams['mappings']` entries. */
export type ImportMappingParam = NonNullable<ImportCompleteMappingParams['mappings']>[number]

/**
 * Owner type passed to the generic `client.customFields(ownerType, ownerId)`
 * escape hatch. The first-class seven (products, variants, orders, customers,
 * categories, collections, option_types) have dedicated
 * `client.<resource>.customFields` accessors and don't need this.
 */
export type CustomFieldOwnerType =
  | 'product'
  | 'variant'
  | 'order'
  | 'customer'
  | 'category'
  | 'collection'
  | 'option_type'
  | (string & {})

export type PromotionKind = 'coupon_code' | 'automatic'

/** @deprecated Renamed to `PromotionRuleDraftParams`. */
export type PromotionRuleDraft = PromotionRuleDraftParams

/** @deprecated Renamed to `PromotionActionDraftParams`. */
export type PromotionActionDraft = PromotionActionDraftParams

/**
 * One entry returned by `GET /promotion_actions/calculators?type=…` — a
 * calculator subclass available for the given action, with the preference
 * fields the SPA renders below the calculator picker.
 */
export interface PromotionActionCalculator {
  type: string
  label: string
  /** JSON Schema of the type's `preferences`. */
  schema: PreferenceSchema
}

// ============================================
// Saved reports (semantic reporting layer)
// ============================================

/**
 * The outstanding balance for one currency, summed over the filter the list
 * request used. Amounts are decimal strings written with the currency's
 * decimals; format them for display on the client.
 */
export interface StoreCreditCurrencyTotal {
  currency: string
  /** Everything ever issued in this currency. */
  amount: string
  /** How much of it has been spent. */
  amount_used: string
  /** How much is committed to an in-flight authorization. */
  amount_authorized: string
  /** What the store still owes: issued minus used minus authorized. */
  amount_remaining: string
}

export interface StoreCreditListMeta extends PaginationMeta {
  /** One row per currency present in the filtered scope, ordered by currency. */
  totals: StoreCreditCurrencyTotal[]
}

export interface StoreCreditListResponse {
  data: StoreCredit[]
  meta: StoreCreditListMeta
}

export type EmailTemplateLanguageParams = {
  /** A language code, or `any` (the default) for the version every language uses. */
  language?: string
}
