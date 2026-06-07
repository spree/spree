// Request parameter types for Admin API endpoints
// Based on the Admin API OpenAPI specification

export interface StoreUpdateParams {
  name?: string
  preferred_admin_locale?: string
  preferred_timezone?: string
  preferred_weight_unit?: string
  preferred_unit_system?: string
  /** Sender address used on all transactional emails (required by the model). */
  mail_from_address?: string
  /** Customer-facing reply-to address shown in the storefront/email footer. */
  customer_support_email?: string | null
  /** Recipient of "new order placed" admin notifications. */
  new_order_notifications_email?: string | null
  /** When false, transactional consumer emails (order confirmation, etc.) are suppressed. */
  preferred_send_consumer_transactional_emails?: boolean
  /** Active Storage signed_id from a direct upload — the logo embedded in transactional emails. */
  mailer_logo?: string | null
}

export interface OptionValueParams {
  /** Present for existing rows. Omit to create a new value. */
  id?: string
  name?: string
  label?: string
  position?: number
  /** Hex color (e.g. `#FF0000`). Only meaningful when the parent option type's `kind` is `color_swatch`. */
  color_code?: string | null
  /** Active Storage signed_id from a direct upload. */
  image?: string | null
}

export interface OptionTypeCreateParams {
  name: string
  label: string
  position?: number
  filterable?: boolean
  /** `dropdown`, `color_swatch`, or `buttons`. */
  kind?: string
  /**
   * Inline option values. Values omitted from the array on update are destroyed —
   * send the full set every time you write.
   */
  option_values?: Array<OptionValueParams>
}

export interface OptionTypeUpdateParams {
  name?: string
  label?: string
  position?: number
  filterable?: boolean
  kind?: string
  option_values?: Array<OptionValueParams>
}

export interface LineItemCreateParams {
  variant_id: string
  quantity?: number
}

export interface LineItemUpdateParams {
  quantity?: number
}

export interface PaymentCreateParams {
  payment_method_id: string
  /**
   * Decimal amount. Accept `string` so callers can ship the merchant's
   * raw input verbatim — `Spree::LocalizedNumber.parse` handles
   * locale-aware decoding (comma decimals, grouped digits, etc.) on the
   * backend; `Number()`-coercing on the frontend would mangle inputs
   * like `"1.234,56"` into `NaN`.
   */
  amount?: string | number
  source_id?: string
}

export interface RefundCreateParams {
  payment_id: string
  /** Decimal amount; see `PaymentCreateParams.amount` for the string rationale. */
  amount: string | number
  refund_reason_id?: string
}

export interface FulfillmentUpdateParams {
  tracking?: string
  selected_delivery_rate_id?: string
}

export interface AddressInputParams {
  first_name?: string
  last_name?: string
  address1?: string
  address2?: string
  city?: string
  postal_code?: string
  country_iso?: string
  state_abbr?: string
  phone?: string
  company?: string
}

export interface OrderCreateParams {
  email?: string
  customer_id?: string
  user_id?: string
  use_customer_default_address?: boolean
  currency?: string
  market_id?: string
  /** Channel ID. Defaults to the store primary channel when omitted. */
  channel_id?: string
  /**
   * Stock Location ID to prefer for fulfillment. Order Routing's built-in
   * `PreferredLocation` rule reads this and ranks the location first;
   * routing falls back to the next rule when the preferred location can't
   * cover the cart.
   */
  preferred_stock_location_id?: string
  locale?: string
  customer_note?: string
  internal_note?: string
  metadata?: Record<string, unknown>
  shipping_address?: AddressInputParams
  shipping_address_id?: string
  billing_address?: AddressInputParams
  billing_address_id?: string
  items?: Array<{
    variant_id: string
    quantity: number
    metadata?: Record<string, unknown>
  }>
  /** Optional. Applied non-fatally; invalid codes do not block creation. */
  coupon_code?: string
}

export interface OrderUpdateParams {
  email?: string
  customer_id?: string
  customer_note?: string
  internal_note?: string
  ship_address?: AddressInputParams
  bill_address?: AddressInputParams
  line_items?: Array<{
    variant_id?: string
    quantity?: number
  }>
}

export interface OrderCompleteParams {
  payment_pending?: boolean
  notify_customer?: boolean
}

export interface OrderCancelParams {
  reason?: 'customer' | 'declined' | 'fraud' | 'inventory' | 'staff' | 'other' | 'expired'
  note?: string
  restock_items?: boolean
  refund_payments?: boolean
  refund_amount?: number
  notify_customer?: boolean
}

export interface OrderApproveParams {
  level?: string
  note?: string
}

export interface GiftCardApplyParams {
  code: string
}

/**
 * Admin-issued gift card. `code` is optional — the server auto-generates
 * a unique code when omitted. `currency` defaults to the store's currency.
 * `user_id` (customer prefixed ID) attaches the card to a specific customer.
 */
export interface GiftCardCreateParams {
  amount: string | number
  currency?: string
  code?: string
  expires_at?: string | null
  user_id?: string | null
}

export interface GiftCardUpdateParams {
  amount?: string | number
  expires_at?: string | null
  user_id?: string | null
}

/**
 * Bulk-issue a `codes_count`-sized batch of gift cards. The server generates
 * codes by suffixing random hex onto `prefix`. Small batches generate inline;
 * large ones (over `gift_card_batch_web_limit`, default 500) enqueue a
 * background job.
 */
export interface GiftCardBatchCreateParams {
  prefix: string
  amount: string | number
  codes_count: number
  currency?: string
  expires_at?: string | null
}

export interface StoreCreditApplyParams {
  /** Decimal amount; see `PaymentCreateParams.amount` for the string rationale. */
  amount?: string | number
}

export interface CustomerCreateParams {
  email: string
  first_name?: string
  last_name?: string
  phone?: string
  accepts_email_marketing?: boolean
  internal_note?: string
  metadata?: Record<string, unknown>
  tags?: string[]
}

export interface CustomerUpdateParams {
  email?: string
  first_name?: string
  last_name?: string
  phone?: string
  accepts_email_marketing?: boolean
  internal_note?: string
  metadata?: Record<string, unknown>
  tags?: string[]
}

export interface CustomerAddressParams {
  firstname?: string
  lastname?: string
  first_name?: string
  last_name?: string
  address1?: string
  address2?: string
  city?: string
  zipcode?: string
  postal_code?: string
  country_id?: string
  state_id?: string
  country_iso?: string
  state_abbr?: string
  phone?: string
  company?: string
  label?: string
  is_default_billing?: boolean
  is_default_shipping?: boolean
}

export interface CustomerStoreCreditCreateParams {
  /** Decimal amount; see `PaymentCreateParams.amount` for the string rationale. */
  amount: string | number
  currency: string
  category_id: string
  memo?: string
}

export interface CustomerStoreCreditUpdateParams {
  /** Decimal amount; see `PaymentCreateParams.amount` for the string rationale. */
  amount?: string | number
  category_id?: string
  memo?: string
}

export interface DirectUploadCreateParams {
  blob: {
    filename: string
    byte_size: number
    checksum: string
    content_type: string
  }
}

export interface MediaCreateParams {
  alt?: string
  position?: number
  type?: string
  url?: string
  signed_id?: string
  // Prefixed or raw variant IDs to link this product-level media to. Variants
  // not on the same product are silently dropped server-side.
  variant_ids?: Array<string>
}

export interface MediaUpdateParams {
  alt?: string
  position?: number
  // Replaces the full set of variants this media is linked to. Empty array
  // clears all links; omit the field entirely to leave links untouched.
  variant_ids?: Array<string>
}

export interface ProductPublicationInput {
  channel_id: string
  published_at?: string | null
  unpublished_at?: string | null
}

export interface ProductCreateParams {
  name: string
  description?: string
  slug?: string
  status?: 'draft' | 'active' | 'archived'
  tax_category_id?: string
  category_ids?: Array<string>
  tags?: Array<string>
  /** Every purchasable attribute (sku, prices, stock, weight, dimensions) lives
   *  on variants. Pass at least one variant to make the product purchasable. */
  variants?: VariantCreateParams[]
  product_publications?: ProductPublicationInput[]
}

export interface ProductUpdateParams {
  name?: string
  description?: string
  slug?: string
  status?: 'draft' | 'active' | 'archived'
  tax_category_id?: string
  category_ids?: Array<string>
  tags?: Array<string>
  variants?: VariantUpdateParams[]
  product_publications?: ProductPublicationInput[]
}

export interface CategoryCreateParams {
  name: string
  parent_id?: string
  position?: number
  description?: string
  permalink?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  hide_from_nav?: boolean
  sort_order?: string
}

export interface CategoryUpdateParams {
  name?: string
  parent_id?: string
  position?: number
  description?: string
  permalink?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  hide_from_nav?: boolean
  sort_order?: string
}

export interface VariantOptionPair {
  name: string
  value: string
}

export interface VariantPrice {
  currency: string
  /**
   * Decimal amount. Accept `string` so callers ship the merchant's raw
   * input verbatim — `Spree::LocalizedNumber.parse` on the backend
   * handles locale-aware decoding (comma decimals, grouped digits, etc.);
   * `Number()`-coercing in the frontend mangles inputs like `"1.234,56"`
   * into `NaN`.
   */
  amount: string | number
  compare_at_amount?: string | number | null
}

export interface VariantStockItem {
  stock_location_id: string
  count_on_hand: number
  backorderable?: boolean
}

export interface VariantCreateParams {
  sku?: string
  /** Decimal amount; see `VariantPrice.amount` for the string rationale. */
  compare_at_price?: string | number
  /** Decimal amount; see `VariantPrice.amount` for the string rationale. */
  cost_price?: string | number
  cost_currency?: string
  weight?: number
  height?: number
  width?: number
  depth?: number
  weight_unit?: string
  dimensions_unit?: string
  track_inventory?: boolean
  tax_category_id?: string
  position?: number
  barcode?: string
  options?: VariantOptionPair[]
  prices?: VariantPrice[]
  stock_items?: VariantStockItem[]
}

export interface VariantUpdateParams {
  sku?: string
  /** Decimal amount; see `VariantPrice.amount` for the string rationale. */
  compare_at_price?: string | number
  /** Decimal amount; see `VariantPrice.amount` for the string rationale. */
  cost_price?: string | number
  cost_currency?: string
  weight?: number
  height?: number
  width?: number
  depth?: number
  weight_unit?: string
  dimensions_unit?: string
  track_inventory?: boolean
  tax_category_id?: string
  position?: number
  barcode?: string
  options?: VariantOptionPair[]
  prices?: VariantPrice[]
  stock_items?: VariantStockItem[]
}

export interface CustomFieldCreateParams {
  custom_field_definition_id: string
  value: unknown
}

export interface CustomFieldUpdateParams {
  value: unknown
}

export interface CustomFieldDefinitionCreateParams {
  namespace?: string
  key: string
  label?: string
  field_type: string
  resource_type: string
  storefront_visible?: boolean
}

export interface CustomFieldDefinitionUpdateParams {
  namespace?: string
  key?: string
  label?: string
  field_type?: string
  storefront_visible?: boolean
}

export interface ApiKeyCreateParams {
  name: string
  key_type: 'publishable' | 'secret'
  /** Required for `key_type: 'secret'`. See `Spree::ApiKey::SCOPES` for the full list. */
  scopes?: string[]
}

export interface ApiKeyUpdateParams {
  /** `key_type` is set on create only — flipping types invalidates downstream consumers. */
  name?: string
  scopes?: string[]
}

export interface InvitationCreateParams {
  email: string
  /** Prefixed role ID (e.g. `role_xxx`). */
  role_id: string
}

/**
 * Body for accepting an invitation. Empty for existing accounts when no
 * password change is needed; populated with `password` (and optionally
 * `password_confirmation` + names) for new accounts being created on accept.
 */
export interface InvitationAcceptParams {
  password?: string
  password_confirmation?: string
  first_name?: string
  last_name?: string
}

export interface AdminUserUpdateParams {
  first_name?: string
  last_name?: string
  /** Prefixed role IDs scoped to the current store. Treated as a complete replacement. */
  role_ids?: string[]
}

export interface StockLocationCreateParams {
  name: string
  admin_name?: string | null
  active?: boolean
  default?: boolean
  /** Built-in values: 'warehouse' | 'store' | 'fulfillment_center'. Open string — plugins can register custom kinds. */
  kind?: string
  propagate_all_variants?: boolean
  backorderable_default?: boolean
  address1?: string | null
  address2?: string | null
  city?: string | null
  zipcode?: string | null
  phone?: string | null
  company?: string | null
  /** ISO-3166 alpha-2 country code (e.g. 'US'). */
  country_iso?: string | null
  /** State / province abbreviation (e.g. 'NY'). Resolved against the selected country's states. */
  state_abbr?: string | null
  /** Free-text state for countries that don't have a states list. */
  state_name?: string | null
  pickup_enabled?: boolean
  /** 'local' = items at this location only; 'any' = transfer-eligible (ship-to-store). */
  pickup_stock_policy?: 'local' | 'any'
  pickup_ready_in_minutes?: number | null
  pickup_instructions?: string | null
}

export interface StockLocationUpdateParams {
  name?: string
  admin_name?: string | null
  active?: boolean
  default?: boolean
  kind?: string
  propagate_all_variants?: boolean
  backorderable_default?: boolean
  address1?: string | null
  address2?: string | null
  city?: string | null
  zipcode?: string | null
  phone?: string | null
  company?: string | null
  country_iso?: string | null
  state_abbr?: string | null
  state_name?: string | null
  pickup_enabled?: boolean
  pickup_stock_policy?: 'local' | 'any'
  pickup_ready_in_minutes?: number | null
  pickup_instructions?: string | null
}

export interface StockItemUpdateParams {
  count_on_hand?: number
  backorderable?: boolean
  metadata?: Record<string, unknown>
}

export interface StockTransferCreateParams {
  /** Omit for a vendor receive (external stock arriving at the destination). */
  source_location_id?: string
  destination_location_id: string
  reference?: string
  variants: Array<{ variant_id: string; quantity: number }>
}

export interface AllowedOriginCreateParams {
  /**
   * Origin to allow in admin CORS preflight checks. Must be a bare
   * `scheme://host[:port]` (no path, query, or fragment) and use `http` or
   * `https`.
   */
  origin: string
}

export interface AllowedOriginUpdateParams {
  origin?: string
}

export interface WebhookEndpointCreateParams {
  /** Optional human label shown in the admin list view. */
  name?: string | null
  /** HTTPS destination URL. Cannot resolve to a private IP outside development. */
  url: string
  /** Defaults to true on create. Toggle with `disable`/`enable` for audit clarity. */
  active?: boolean
  /**
   * Event names this endpoint should receive. Empty array or `['*']` subscribes
   * to all events; otherwise list exact event names (e.g. `order.completed`) or
   * patterns (e.g. `order.*`).
   */
  subscriptions?: string[]
}

export interface WebhookEndpointUpdateParams {
  name?: string | null
  url?: string
  active?: boolean
  subscriptions?: string[]
}

export interface WebhookEndpointDisableParams {
  /** Optional human-readable reason shown next to the disabled indicator. */
  reason?: string
}

export interface TaxCategoryCreateParams {
  name: string
  tax_code?: string | null
  description?: string | null
  is_default?: boolean
}

export interface TaxCategoryUpdateParams {
  name?: string
  tax_code?: string | null
  description?: string | null
  is_default?: boolean
}

export interface MarketCreateParams {
  /** Display name (unique per store, e.g. "Europe"). */
  name: string
  /** ISO 4217 currency code (e.g. "EUR"). */
  currency: string
  /** IETF locale tag used as the market default (e.g. "de"). Always included in `supported_locales`. */
  default_locale: string
  /** Additional supported locales — the default is always implicitly present. */
  supported_locales?: string[]
  /** Display prices with tax included. */
  tax_inclusive?: boolean
  /** Setting `true` demotes the previous default in the store. */
  default?: boolean
  /** Sort order within the store; lower = first. */
  position?: number
  /** 2-letter ISO country codes assigned to this market. At least one is required. */
  country_isos: string[]
}

export interface MarketUpdateParams {
  name?: string
  currency?: string
  default_locale?: string
  supported_locales?: string[]
  tax_inclusive?: boolean
  default?: boolean
  position?: number
  country_isos?: string[]
}

export interface CustomerGroupCreateParams {
  name: string
  description?: string | null
  customer_ids?: string[]
}

export interface ChannelCreateParams {
  name: string
  /**
   * URL-safe slug. Optional — the backend derives it from +name+ when omitted
   * (e.g. "Point of Sale" → "point-of-sale").
   */
  code?: string
  active?: boolean
  default?: boolean
  /**
   * Class name of a +Spree::OrderRouting::Strategy::Base+ subclass, or +null+
   * to inherit the store-level preference.
   */
  preferred_order_routing_strategy?: string | null
}

export interface ChannelUpdateParams {
  name?: string
  code?: string
  active?: boolean
  default?: boolean
  preferred_order_routing_strategy?: string | null
}

export interface CustomerGroupUpdateParams {
  name?: string
  description?: string | null
  customer_ids?: string[]
}

/**
 * One entry in `preference_schema`, describing a single tunable knob on
 * a STI subclass (payment provider, promotion action, promotion rule).
 *
 * The `type` mirrors Spree's preference type system — `string`, `text`,
 * `integer`, `decimal`, `boolean`, `array`, `password` — so admin UIs
 * can switch on it to render the right input widget.
 */
export interface PreferenceField {
  key: string
  type: string
  default: unknown
}

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
 * registered subclass with its preference schema. Used to build "Add
 * provider / action / rule" pickers and render generic preferences forms.
 */
export interface ResourceTypeDefinition {
  type: string
  label: string
  description: string | null
  preference_schema: PreferenceField[]
}

// ---------------------------------------------------------------------------
// Price Lists
// ---------------------------------------------------------------------------

/**
 * Nested-rule payload accepted by both create and update. Existing rules
 * are matched by `id` and updated, new rules build, anything not in the
 * array is destroyed — mirrors the Promotions editor's "save the whole
 * thing in one PATCH" flow.
 */
export interface PriceListRuleDraft {
  /** Present for existing rules. Omit to create a new one. */
  id?: string | null
  /** Wire shorthand for the STI subclass — e.g. `volume_rule`, `market_rule`. */
  type: string
  /** Subclass-specific configuration; coerced server-side via typed preference setters. */
  preferences?: Record<string, unknown>
}

export interface PriceListCreateParams {
  name: string
  description?: string | null
  /**
   * ISO 8601 timestamp. Pair with `ends_at` to schedule the list — an
   * activated list with a future `starts_at` is auto-marked `scheduled`
   * (mirrors the legacy admin).
   */
  starts_at?: string | null
  ends_at?: string | null
  /** `all` — every rule must match. `any` — first match wins. */
  match_policy?: 'all' | 'any'
  position?: number
  /**
   * Admin UI shape. Prefixed product ids to seed the list with —
   * placeholder prices (`amount: null`) are inserted for each variant
   * × supported currency. The spreadsheet editor then fills them in.
   *
   * Prefer `prices` for server-to-server use: it lets you create the
   * list and ship the exact per-variant amounts in one request.
   */
  product_ids?: string[]
  /** Optional nested rules — reconciled on save. */
  rules?: PriceListRuleDraft[]
  /**
   * Server-to-server alternative to `product_ids`. Each row upserts on
   * `(variant_id, currency, price_list_id)`, so variants in this array
   * implicitly become part of the list with the supplied amount.
   */
  prices?: PriceListPriceOverrideParams[]
}

export interface PriceListUpdateParams {
  name?: string
  description?: string | null
  starts_at?: string | null
  ends_at?: string | null
  match_policy?: 'all' | 'any'
  position?: number
  /**
   * Reconciles list membership: every id in the array is kept (placeholder
   * prices created if missing); every id currently in the list but not in
   * the array is dropped. Send the desired full set on every update —
   * the server diffs it against the current state.
   */
  product_ids?: string[]
  rules?: PriceListRuleDraft[]
  /**
   * Inline spreadsheet payload. Only ship the rows whose `amount` /
   * `compare_at_amount` actually changed — the server skips unchanged
   * cells, but a smaller body is still nicer. Runs in `after_save` so
   * it picks up rows created by `product_ids=` in the same request.
   */
  prices?: PriceListPriceOverrideParams[]
}

/**
 * One row in the inline `prices: [...]` array carried by
 * `PriceListCreateParams` / `PriceListUpdateParams`. The server upserts
 * on the unique key `(variant_id, currency, price_list_id)`, so the
 * row matches by triple — `id` is only useful when echoing back rows
 * read from a previous response. For first-time creates ship
 * `variant_id` + `currency` + `amount` directly.
 */
export interface PriceListPriceOverrideParams {
  id?: string
  variant_id: string
  currency: string
  amount?: string | number | null
  compare_at_amount?: string | number | null
}

// ---------------------------------------------------------------------------
// Prices (generic — base prices AND price-list overrides)
// ---------------------------------------------------------------------------

/**
 * Create or update a single Spree::Price. Set `price_list_id: null`
 * (or omit it) for a base price on the variant; pass a prefixed
 * `pl_…` to attach the row to a price list.
 */
export interface PriceCreateParams {
  variant_id: string
  currency: string
  amount: string | number | null
  compare_at_amount?: string | number | null
  /** Omit / null for a base price; prefixed `pl_…` for a list override. */
  price_list_id?: string | null
}

export interface PriceUpdateParams {
  /** Mutating these would re-key the row against the unique
   *  `(variant_id, currency, price_list_id)` index — not supported. */
  // variant_id, currency, price_list_id intentionally omitted.
  amount?: string | number | null
  compare_at_amount?: string | number | null
}

/**
 * One row in the `POST /admin/prices/bulk_upsert` payload.
 *
 * Two modes, picked by whether `id` is set:
 *
 *   - `id` present → updates that row (404s if it doesn't exist or
 *     is out of the caller's store scope).
 *   - `id` absent  → upserts by `(variant_id, currency, price_list_id)`.
 *     The unique index on `spree_prices` decides update-vs-create.
 *
 * Useful for the spreadsheet (mostly updates) and for ad-hoc seeding
 * a fresh currency across many variants (mostly creates).
 */
export interface PriceBulkUpsertRow {
  /** Present → update by id. Absent → upsert by the unique key. */
  id?: string
  /** Required when `id` is absent. */
  variant_id?: string
  /** Required when `id` is absent. */
  currency?: string
  /** Null / omitted = base price; prefixed `pl_…` = list override. */
  price_list_id?: string | null
  amount?: string | number | null
  compare_at_amount?: string | number | null
}

export interface PaymentMethodCreateParams {
  /** Fully-qualified STI subclass name, e.g. 'Spree::PaymentMethod::Check'. */
  type: string
  name: string
  description?: string | null
  active?: boolean
  /** `false` → admin-only; `true` → also on the storefront. */
  storefront_visible?: boolean
  auto_capture?: boolean | null
  position?: number
  metadata?: Record<string, unknown>
  /** Provider-specific configuration; values are coerced via the typed setters. */
  preferences?: Record<string, unknown>
}

export interface PaymentMethodUpdateParams {
  name?: string
  description?: string | null
  active?: boolean
  /** `false` → admin-only; `true` → also on the storefront. */
  storefront_visible?: boolean
  auto_capture?: boolean | null
  position?: number
  metadata?: Record<string, unknown>
  preferences?: Record<string, unknown>
}

/**
 * One entry returned by `GET /payment_methods/types` — the registered list
 * of available STI subclasses, with their per-provider preference schemas
 * for the universal configuration form.
 *
 * @deprecated Prefer `ResourceTypeDefinition`; this alias remains for
 * naming-symmetry with the controller. They are structurally identical.
 */
export type PaymentMethodType = ResourceTypeDefinition

/**
 * Built-in `Spree::Export` subclasses. The server validates `type` against
 * the configured allowlist (`Spree::Export.available_types`); a plugin can
 * register additional types, which arrive here as the trailing `string & {}`
 * arm. Use one of the named constants for autocomplete.
 */
export type ExportType =
  | 'Spree::Exports::Products'
  | 'Spree::Exports::Orders'
  | 'Spree::Exports::Customers'
  | 'Spree::Exports::ProductTranslations'
  | 'Spree::Exports::GiftCards'
  | 'Spree::Exports::CouponCodes'
  | 'Spree::Exports::NewsletterSubscribers'
  | (string & {})

export interface ExportCreateParams {
  /** Which dataset to export. Server validates against `Spree::Export.available_types`. */
  type: ExportType
  /**
   * Ransack query hash. Same predicate shape used on list endpoints
   * (`{ name_cont: 'shirt', price_gt: 10 }`). Ignored when `record_selection`
   * is `'all'`. Use `filtersToRansack(filters, columns)` from the SPA helper
   * to turn the toolbar filter state into this shape.
   */
  search_params?: Record<string, unknown>
  /**
   * `'filtered'` (default) keeps `search_params`; `'all'` clears them on the
   * server and exports every record in scope.
   */
  record_selection?: 'filtered' | 'all'
}

/**
 * Owner type passed to the generic `client.customFields(ownerType, ownerId)`
 * escape hatch. The first-class six (products, variants, orders, customers,
 * categories, option_types) have dedicated `client.<resource>.customFields`
 * accessors and don't need this.
 */
export type CustomFieldOwnerType =
  | 'Spree::Product'
  | 'Spree::Variant'
  | 'Spree::Order'
  | 'Spree::User'
  | 'Spree::Category'
  | 'Spree::OptionType'
  | (string & {})

export type PromotionKind = 'coupon_code' | 'automatic'

export interface PromotionCreateParams {
  name: string
  description?: string | null
  starts_at?: string | null
  expires_at?: string | null
  /** Required for single-code coupon promotions. Ignored when `multi_codes` is true. */
  code?: string | null
  usage_limit?: number | null
  match_policy?: 'all' | 'any'
  path?: string | null
  promotion_category_id?: string | null
  /** `coupon_code` requires a code (or multi_codes); `automatic` triggers without one. */
  kind?: PromotionKind
  /** When true, server auto-generates `number_of_codes` codes prefixed with `code_prefix`. */
  multi_codes?: boolean
  number_of_codes?: number | null
  code_prefix?: string | null
  metadata?: Record<string, unknown>
  /** Optional rules to create alongside the promotion. Sent as a desired-set on update. */
  rules?: PromotionRuleDraft[]
  /** Optional actions to create alongside the promotion. */
  actions?: PromotionActionDraft[]
}

export interface PromotionUpdateParams {
  name?: string
  description?: string | null
  starts_at?: string | null
  expires_at?: string | null
  code?: string | null
  usage_limit?: number | null
  match_policy?: 'all' | 'any'
  path?: string | null
  promotion_category_id?: string | null
  kind?: PromotionKind
  multi_codes?: boolean
  number_of_codes?: number | null
  code_prefix?: string | null
  metadata?: Record<string, unknown>
  /** Replaces the rule set: rows with `id` update, rows without build, missing rows are removed. */
  rules?: PromotionRuleDraft[]
  /** Same desired-set semantic as `rules`. */
  actions?: PromotionActionDraft[]
}

/**
 * One entry in a `Promotion#rules`/`#actions` payload. `id` is optional —
 * supply it on updates to match an existing row, omit for new rows. The
 * server reconciles to the desired set: anything not in the array is
 * removed.
 */
export interface PromotionRuleDraft {
  id?: string
  /**
   * Wire shorthand for the rule subclass (e.g. `'currency'`, `'item_total'`,
   * `'product'`, `'category'`). Returned by `GET /promotion_rules/types`.
   */
  type: string
  preferences?: Record<string, unknown>
  /** For the `product` rule. */
  product_ids?: string[]
  /** For the `category` rule. */
  category_ids?: string[]
  /** For the `user` rule — customers who qualify for the promotion. */
  customer_ids?: string[]
}

export interface PromotionActionDraft {
  id?: string
  /**
   * Wire shorthand for the action subclass (e.g. `'free_shipping'`,
   * `'create_item_adjustments'`, `'create_adjustment'`). Returned by
   * `GET /promotion_actions/types`.
   */
  type: string
  preferences?: Record<string, unknown>
  /** For adjustment actions. */
  calculator?: PromotionActionCalculatorParams
  /** For `create_line_items`. */
  line_items?: PromotionActionLineItemParams[]
}

/**
 * Nested calculator payload for adjustment actions. Sent on
 * `create_adjustment` and `create_item_adjustments`.
 *
 * - `type` — wire shorthand for the calculator subclass (e.g. `'flat_rate'`,
 *   `'flat_percent_item_total'`, `'percent_on_line_item'`); changing the
 *   type swaps the underlying calculator record.
 * - `preferences` — per-calculator preference values (`amount`,
 *   `flat_percent`, `currency`, …). Keys are coerced via the typed
 *   setters server-side.
 */
export interface PromotionActionCalculatorParams {
  type?: string
  preferences?: Record<string, unknown>
}

/**
 * Nested promotion-action line item — one row in the "give the customer
 * variant X with quantity N" payload for `CreateLineItems`. The submitted
 * list is the *desired* set: variants not present are removed, variants
 * present are upserted by `(promotion_action_id, variant_id)`.
 */
export interface PromotionActionLineItemParams {
  variant_id: string
  quantity: number
}

/**
 * One entry returned by `GET /promotion_actions/calculators?type=…` — a
 * calculator subclass available for the given action, with the preference
 * fields the SPA renders below the calculator picker.
 */
export interface PromotionActionCalculator {
  type: string
  label: string
  preference_schema: PreferenceField[]
}

export interface PromotionActionCreateParams {
  /** Wire shorthand for the action subclass (e.g. `'free_shipping'`). */
  type: string
  preferences?: Record<string, unknown>
  /** For adjustment actions — calculator subclass + its preference values. */
  calculator?: PromotionActionCalculatorParams
  /** For `CreateLineItems` — desired set of variants + quantities. */
  line_items?: PromotionActionLineItemParams[]
}

export interface PromotionActionUpdateParams {
  preferences?: Record<string, unknown>
  calculator?: PromotionActionCalculatorParams
  line_items?: PromotionActionLineItemParams[]
}

export interface PromotionRuleCreateParams {
  /** Wire shorthand for the rule subclass (e.g. `'currency'`, `'item_total'`). */
  type: string
  preferences?: Record<string, unknown>
  /** For the `product` rule — prefixed product IDs to associate with this rule. */
  product_ids?: string[]
  /** For the `category` rule — prefixed category IDs. */
  category_ids?: string[]
  /** For the `user` rule — prefixed customer IDs. */
  customer_ids?: string[]
}

export interface PromotionRuleUpdateParams {
  preferences?: Record<string, unknown>
  product_ids?: string[]
  category_ids?: string[]
  customer_ids?: string[]
}
