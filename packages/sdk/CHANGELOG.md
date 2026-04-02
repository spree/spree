# @spree/sdk

## 0.20.0

### Minor Changes

- Add option type `kind` field (dropdown/color_swatch/buttons) and option value `color_code` + `image_url` fields for swatch support

## 0.19.1

### Patch Changes

- Updated types reflecting removal of timestampts from Store API

## 0.19.0

### Minor Changes

- Replace `categories_id_eq` filter and `categories.products.list()` with `in_category` / `in_categories` scopes on the `/products` endpoint. Category filters now include descendant categories.

### Patch Changes

- Rename metafields to custom*fields in Store API. The expand parameter changes from `metafields` to `custom_fields`, and the response key changes accordingly. Prefix IDs change from `mf*`to`cf\_`. The `StoreMetafield`type is replaced by`StoreCustomField`.

- Remove `created_at` and `updated_at` from Store API responses. These internal timestamps are now only available in Admin API responses. Business timestamps like `completed_at` and `expires_at` are unchanged.

## 0.18.0

### Breaking Changes

- **Removed `categories.products.list()`** — use `products.list({ in_category: 'ctg_xxx' })` instead. The dedicated `/categories/{id}/products` endpoint has been removed in favor of the `in_category` scope on `/products`
- **Replaced `categories_id_eq` filter** with `in_category` and `in_categories` scopes

### New Features

- **`in_category` filter** — filter products by category prefixed ID, automatically includes descendant categories
- **`in_categories` filter** — filter by multiple category prefixed IDs with OR logic (checkbox-style filters), each includes descendants

### Bug Fixes

- **Category filtering on PLP** — category filters now correctly include products in descendant categories, fixing empty results on multi-level taxonomy PLPs

## 0.17.0

### New Features

- **Webhook signature verification** — new `@spree/sdk/webhooks` subpath export with `verifyWebhookSignature()` for HMAC-SHA256 signature verification with replay protection. Works with any framework (Express, Hono, Cloudflare Workers, Next.js, etc.)
- **Webhook event types** — `WebhookEvent<T>` generic envelope type. Use existing SDK types (`Order`, `Payment`, `Fulfillment`, etc.) as the type parameter — webhook payloads use the same V3 serializers as the REST API

## 0.16.0

### Breaking Changes

- **Renamed `couponCodes` to `discountCodes`** — `client.carts.discountCodes.apply()` / `.remove()` (was `couponCodes`)
- **Renamed `customer.passwordResets` to `passwordResets`** — moved to top-level: `client.passwordResets.create()` / `.update()`

### New Features

- **Gift cards** — dedicated cart endpoints: `client.carts.giftCards.apply(cartId, code)` and `client.carts.giftCards.remove(cartId, giftCardId)`
- **`amount_due` / `display_amount_due`** — new fields on Cart and Order types showing the amount owed after store credits/gift cards
- **Cart warnings** — every cart response now includes a `warnings` array flagging issues like removed out-of-stock items
- **Gift card error codes** — dedicated error codes: `gift_card_not_found`, `gift_card_expired`, `gift_card_already_redeemed`
- **Store policies** — `client.policies.list()` and `client.policies.get(slug)` for return policy, privacy policy, terms of service, etc.

### Types

- `Cart` type now includes `warnings` array and `amount_due` / `display_amount_due` fields
- New exported type: `CartWarning` (derived from `Cart['warnings'][number]`)
- New exported type: `Policy`

## 0.15.0

### Minor Changes

**Breaking:** Store API endpoint changes requiring backend >= 5.4.0.rc2:

- **Default address:** Removed `markAsDefault()` method. Use `is_default_billing` / `is_default_shipping` booleans on `create()` and `update()` instead (Medusa/Vendure pattern)
- **Removed redundant endpoints:** `carts.paymentMethods.list()`, `carts.payments.list()`, `carts.payments.get()`, `carts.fulfillments.list()` — payment methods, payments, and fulfillments are included in the cart response
- **`AddressParams`** now includes `is_default_billing` and `is_default_shipping` fields
- **Address response** now includes `is_default_billing` and `is_default_shipping` fields
- **Cart/Order response** now includes `store_credit_total`, `gift_card_total`, `covered_by_store_credit`, and `gift_card` association
- **Customer response** now includes `available_store_credit_total`
- **New endpoint:** `customer.storeCredits.list()` and `customer.storeCredits.get()` — store credits for the authenticated customer

## 0.14.2

### Patch Changes

- Restored `gateway_payment_profile_id` on `CreditCard` and `PaymentSource` types — needed by frontends for saved card payment flows (Stripe, Adyen, etc.)

## 0.14.1

### Patch Changes

- Added `use_shipping` option to `UpdateCartParams` — when `true`, copies the shipping address to billing address (billing same as shipping). Write-only flag, not returned in cart responses.
- Added `shipping_eq_billing_address` boolean to Cart — `true` when shipping and billing addresses match. Lets frontends pre-check the "same as shipping" checkbox without comparing addresses manually.

## 0.14.0

### Minor Changes

- Standardize Store API naming against industry conventions (Shopify, Medusa, Saleor, Vendure).

  **Breaking changes:**

  - Address: `firstname` → `first_name`, `lastname` → `last_name`, `zipcode` → `postal_code`
  - Cart/Order: `special_instructions` → `customer_note`, `item_count` → `total_quantity`, `promo_total` → `discount_total`, `bill_address` → `billing_address`, `ship_address` → `shipping_address`, `promotions` → `discounts`
  - LineItem: `promo_total` → `discount_total`
  - OptionType/OptionValue: `presentation` → `label`
  - CreditCard: `cc_type` → `brand`, `last_digits` → `last4`, removed `gateway_payment_profile_id`
  - ReturnAuthorization: `state` → `status`
  - `CartPromotion`/`OrderPromotion` types replaced by unified `Discount` type
  - `WishedItem` type replaced by `WishlistItem`
  - `UpdateCartParams`: `ship_address` → `shipping_address`, `bill_address` → `billing_address`, `special_instructions` → `customer_note`
  - `AddressParams`: `firstname` → `first_name`, `lastname` → `last_name`, `zipcode` → `postal_code`
  - Promotion type slimmed to `id`, `name`, `description`, `code`
  - Product filters: `presentation` → `label`
  - Removed admin-only types from Store SDK (Asset, StockItem, StockMovement, StockTransfer, ShippingCategory, Reimbursement, Report, Export, Import, ImportRow, TaxCategory, CustomerReturn)

## 0.13.2

### Patch Changes

- Rename `multi_search` to `search` in `ProductListParams` and `OrderListParams`. The `multi_search` param still works via backward compatibility on the backend but `search` is now the recommended parameter name for full-text search.

## 0.13.1

### Patch Changes

- Changed generated TypeScript types from `type` aliases to `interface` declarations, enabling declaration merging for SDK consumers who customize API serializers

## 0.13.0

### Minor Changes

- ### Refresh token support

  - `AuthTokens` type now includes `refresh_token` field — returned by login, register, and password reset
  - `client.auth.refresh({ refresh_token })` — exchanges a refresh token for a new access JWT + rotated refresh token. No Authorization header needed.
  - `client.auth.logout({ refresh_token })` — revokes the refresh token server-side

## 0.12.1

### Patch Changes

- Added `items` field to `Fulfillment` type — an array of `{ item_id, variant_id, quantity }` showing which line items (and how many) are in each fulfillment. Enables storefronts to correctly display per-fulfillment item lists for split-shipment orders.

## 0.12.0

### Minor Changes

- ### Breaking: Shipping → Delivery/Fulfillment naming

  Renamed all shipping/shipment API surface to use delivery/fulfillment vocabulary:

  - `client.carts.shipments` → `client.carts.fulfillments`
  - `selected_shipping_rate_id` param → `selected_delivery_rate_id`
  - `/carts/:id/shipments` endpoint → `/carts/:id/fulfillments`

  ### Breaking: Renamed response fields

  - `shipment_state` → `fulfillment_status` (on Order)
  - `payment_state` → `payment_status` (on Order)
  - `ship_total` / `display_ship_total` → `delivery_total` / `display_delivery_total` (on Cart/Order)
  - `state` → `status` (on Payment, GiftCard)
  - `shipped_at` → `fulfilled_at` (on Fulfillment)
  - `shipping_method` → `delivery_method` (on Fulfillment, DeliveryRate)
  - `shipping_rates` → `delivery_rates` (on Fulfillment)

  ### Breaking: Removed fields

  - Removed `is_master` from Variant
  - Removed `expand=master_variant` from Product (use `expand=default_variant`)

  ### Type renames

  - `Shipment` → `Fulfillment` / `StoreFulfillment`
  - `ShippingMethod` → `DeliveryMethod` / `StoreDeliveryMethod`
  - `ShippingRate` → `DeliveryRate` / `StoreDeliveryRate`

### Patch Changes

- Added `items` field to `Fulfillment` type — an array of `{ item_id, variant_id, quantity }` showing which line items (and how many) are in each fulfillment. Enables storefronts to correctly display per-fulfillment item lists for split-shipment orders.

## 0.12.0

### Minor Changes

- ### Breaking: Shipping → Delivery/Fulfillment naming

  Renamed all shipping/shipment API surface to use delivery/fulfillment vocabulary:

  - `client.carts.shipments` → `client.carts.fulfillments`
  - `selected_shipping_rate_id` param → `selected_delivery_rate_id`
  - `/carts/:id/shipments` endpoint → `/carts/:id/fulfillments`

  ### Breaking: Renamed response fields

  - `shipment_state` → `fulfillment_status` (on Order)
  - `payment_state` → `payment_status` (on Order)
  - `ship_total` / `display_ship_total` → `delivery_total` / `display_delivery_total` (on Cart/Order)
  - `state` → `status` (on Payment, GiftCard)
  - `shipped_at` → `fulfilled_at` (on Fulfillment)
  - `shipping_method` → `delivery_method` (on Fulfillment, DeliveryRate)
  - `shipping_rates` → `delivery_rates` (on Fulfillment)

  ### Breaking: Removed fields

  - Removed `is_master` from Variant
  - Removed `expand=master_variant` from Product (use `expand=default_variant`)

  ### Type renames

  - `Shipment` → `Fulfillment` / `StoreFulfillment`
  - `ShippingMethod` → `DeliveryMethod` / `StoreDeliveryMethod`
  - `ShippingRate` → `DeliveryRate` / `StoreDeliveryRate`

## 0.11.0

### Minor Changes

- **Breaking:** Rename `images` to `media` across the Store API
  - `expand: ['images']` → `expand: ['media']` on products and variants
  - Response key `images` → `media`
  - `Image` type replaced by `Media` type (with `media_type`, `product_id`, `focal_point_x/y`, `external_video_url`)
  - `StoreImage` type replaced by `StoreMedia`
  - Removed `viewable_id` and `viewable_type` from media responses
  - Added `product_id` field to media responses

## 0.10.1

### Patch Changes

- Add optional `redirect_url` parameter to `requestPasswordReset` for password reset flow. The URL is validated against the store's allowed origins on the server side.

## 0.10.0

### Minor Changes

- Unified cart and checkout under single `carts` resource

  **Breaking changes:**

  - Removed `client.cart` (singular) and `client.checkout` namespaces
  - All cart and checkout operations are now under `client.carts`
  - All operations on a specific cart now require `cartId` as the first argument
  - `UpdateCheckoutParams` renamed to `UpdateCartParams`

  **Migration guide:**

  ```typescript
  // Before (0.9.x)
  client.cart.create();
  client.cart.get(options);
  client.cart.items.create(params, options);
  client.checkout.update(params, options);
  client.checkout.complete(options);
  client.checkout.shipments.list(options);
  client.checkout.payments.create(params, options);
  client.checkout.paymentSessions.create(params, options);

  // After (0.10.0)
  client.carts.create();
  client.carts.get(cartId, options);
  client.carts.items.create(cartId, params, options);
  client.carts.update(cartId, params, options);
  client.carts.complete(cartId, options);
  client.carts.shipments.list(cartId, options);
  client.carts.payments.create(cartId, params, options);
  client.carts.paymentSessions.create(cartId, params, options);
  ```

## 0.9.0

### Minor Changes

- **Breaking:** Cart API no longer returns `state`, `checkout_steps`, or `state_lock_version`. These are replaced by:

  - `current_step` — the current checkout step (e.g. `"address"`, `"delivery"`, `"payment"`)
  - `completed_steps` — array of steps already completed
  - `requirements` — array of `{ step, field, message }` objects describing what's still needed to complete checkout

- Added `CheckoutRequirement` type for the new `requirements` field on `Cart`.

- **Breaking:** `line_items` renamed to `items` in both `Cart` and `Order` responses.

- **Breaking:** `order_promotions` renamed to `promotions` in both `Cart` and `Order` responses. Cart promotions use `CartPromotion` type (with `cpromo_` prefixed IDs), Order promotions use `OrderPromotion` (with `oprom_` prefixed IDs).

- Added `CartPromotion` type and `CartPromotionSchema` Zod schema.

- `OrderPromotion` now has a prefixed ID (`oprom_`).

- Zod generator now supports inline object types (`Array<{...}>`) and correctly handles nested braces in TypeScript type definitions.

## 0.8.2

### Patch Changes

- Added `orders.payments.create()` method for non-session payment methods (e.g. Check, Cash on Delivery, Bank Transfer). Accepts `payment_method_id`, optional `amount`, and optional `metadata`. For session-based payment methods, use `orders.paymentSessions.create()` instead. Added `CreatePaymentParams` type.

## 0.8.1

### Patch Changes

- Renamed Taxons/Taxonomies to Categories in the public API surface. `client.taxons` is now `client.categories`, `client.taxonomies` has been removed. Types `Taxon`/`Taxonomy` replaced with `Category`. Filter types updated accordingly (`TaxonFilter` → `CategoryFilter`, `TaxonListParams` → `CategoryListParams`, `ProductFiltersParams.taxon_id` → `category_id`).

## 0.8.0

### Minor Changes

- **Breaking:** Move customer registration from `auth.register()` to `customers.create()`. The API endpoint changed from `POST /auth/register` to `POST /customers`, aligning with RESTful resource conventions. The method signature and parameters remain the same — only the namespace changed.

  ```typescript
  // Before
  const auth = await client.auth.register({ email, password, ... })

  // After
  const auth = await client.customers.create({ email, password, ... })
  ```

### Patch Changes

- Updated dependencies:
  - @spree/next@0.8.0

## 0.7.2

### Patch Changes

- Added `phone`, `accepts_email_marketing`, and `metadata` fields to `RegisterParams` for customer registration. Added `metadata` and `current_password` fields to `customer.update()` params. The `Customer` type now includes `phone` and `accepts_email_marketing` fields returned from the Store API.

- Moved `AuthTokens`, `LoginCredentials`, and `RegisterParams` types from `@spree/sdk-core` to `@spree/sdk`. These are store-specific auth types and don't belong in the shared core package. No changes needed for consumers — they are still exported from `@spree/sdk`.

## 0.7.1

### Patch Changes

- Fix `workspace:*` protocol leaking into published package. Internal `@spree/sdk-core` dependency is now bundled at build time instead of declared as a runtime dependency.

## 0.7.0

### Minor Changes

- Flatten client API — `createClient()` replaces `createSpreeClient()`, all store resources are now top-level (`client.products.list()` instead of `client.store.products.list()`). Generated types are re-exported with unprefixed names (`Product` instead of `StoreProduct`; prefixed `Store*` names remain as backward-compatible aliases). Shared HTTP client, retry logic, and param utilities extracted to internal `@spree/sdk-core` package.

### Patch Changes

- Added `checkout_steps` field to `StoreOrder` type. Returns an array of applicable checkout step names for the order (e.g., `["address", "delivery", "payment", "complete"]`). Steps are dynamic per order — digital-only orders may skip `delivery`, free orders may skip `payment`. Use alongside `state` to build dynamic checkout step indicators.

- Added `fields` parameter support for field selection. Pass `fields: ['name', 'slug', 'price']` to `list` and `get` methods to receive only specific fields in the response. The `id` field is always included. Omit `fields` to return all fields (default behavior).

- Switch API `sort` parameter to JSON:API standard `-field` notation. Use `-price` for descending and `price` for ascending instead of `price desc` / `price asc`. The `sort` parameter is now supported on all list endpoints (products, taxons, orders, taxonomies, etc.).

- Added support for nested expand with dot notation. Pass `expand: ['variants.images']` to expand associations up to 4 levels deep. No SDK code changes required — this is a backend feature that works with the existing SDK.

## 0.6.9

### Patch Changes

- Added `checkout_steps` field to `StoreOrder` type. Returns an array of applicable checkout step names for the order (e.g., `["address", "delivery", "payment", "complete"]`). Steps are dynamic per order — digital-only orders may skip `delivery`, free orders may skip `payment`. Use alongside `state` to build dynamic checkout step indicators.

- Added `fields` parameter support for field selection. Pass `fields: ['name', 'slug', 'price']` to `list` and `get` methods to receive only specific fields in the response. The `id` field is always included. Omit `fields` to return all fields (default behavior).

- Added `LineItemInput` type and `line_items` parameter to `CreateCartParams` and `UpdateOrderParams`. You can now pass line items when creating a cart or updating an order, enabling bulk add/upsert of items in a single API call.

  ```typescript
  // Create a cart with line items
  const cart = await client.cart.create({
    line_items: [
      { variant_id: "variant_abc123", quantity: 2 },
      { variant_id: "variant_def456", quantity: 1 },
    ],
  });

  // Upsert line items on an existing order
  const order = await client.orders.update(
    "or_abc123",
    {
      line_items: [{ variant_id: "variant_abc123", quantity: 3 }],
    },
    { bearerToken: "<token>" }
  );
  ```

- Switch API `sort` parameter to JSON:API standard `-field` notation. Use `-price` for descending and `price` for ascending instead of `price desc` / `price asc`. The `sort` parameter is now supported on all list endpoints (products, taxons, orders, taxonomies, etc.).

- Added support for nested expand with dot notation. Pass `expand: ['variants.images']` to expand associations up to 4 levels deep. No SDK code changes required — this is a backend feature that works with the existing SDK.

## 0.6.8

### Patch Changes

- Monetary amount types (`cost`, `amount`, `amount_used`, `amount_authorized`, `amount_remaining`, `cost_price`) changed from `number` to `string` in `StoreShippingRate`, `StoreGiftCard`, `AdminProduct`, and `AdminVariant` types. This follows the Stripe convention of serializing financial values as strings to preserve decimal precision across JSON parsers.

- Fixed `StoreCountry.market` type from `unknown` to `StoreMarket | null`.

- Add `idempotencyKey` option to `RequestOptions` and auto-generate idempotency keys for all mutating requests (POST, PUT, PATCH, DELETE) when retries are enabled. This enables safe automatic retries on 5xx errors and network failures for all requests, matching Stripe SDK behavior. User-supplied keys take precedence over auto-generated ones.

- Added `ListResponse<T>` type for non-paginated list endpoints (countries, currencies, locales, markets). `PaginatedResponse<T>` now extends `ListResponse<T>`.

- Made `publishableKey` optional in client config. Admin-only consumers no longer need to provide a publishable key. At least one of `publishableKey` or `secretKey` must still be provided.

- Stop sending `orderToken` as a URL query parameter. The order token is now sent exclusively via the `x-spree-order-token` header, keeping auth tokens out of URLs (server logs, browser history, referrer headers).

- Removed `store.store` resource from the SDK. Store branding should be configured as developer config (env vars) rather than fetched from the API.

## 0.6.7

### Patch Changes

- Standardize `expand` parameter to accept only `string[]`

## 0.6.6

### Patch Changes

- Rename `per_page` pagination parameter to `limit`
- Rename `includes` query parameter to `expand`

## 0.6.3

### Patch Changes

- Add Markets API support and simplify Country type

  - Add `StoreMarket` type with `id`, `name`, `currency`, `default_locale`, `supported_locales`, `tax_inclusive`, `default`, and optional `countries`
  - Add `client.markets` with `list()`, `get(id)`, `resolve(country)`, and nested `countries.list(marketId)` / `countries.get(marketId, iso)`
  - **Breaking:** Remove `currency`, `default_locale`, `supported_locales` from `StoreCountry` — these now live on `StoreMarket`. Use `?include=market` on the countries endpoint or the markets endpoint directly
  - Add optional `market?: StoreMarket` field to `StoreCountry` (populated when `?include=market` is passed)

## 0.6.2

### Patch Changes

- Added `quick_checkout` attribute to Address type and AddressParams interface

- Add `state_lock_version` to `StoreOrder` and `AdminOrder` response types. The API now returns a `state_lock_version` field on order responses for tracking order mutation versions.

## 0.6.1

### Patch Changes

- Added client-level locale, currency, and country defaults. Set them at initialization (`createSpreeClient({ locale: 'fr', currency: 'EUR', country: 'FR' })`) or update later with `client.setLocale()`, `client.setCurrency()`, `client.setCountry()`. Per-request options still override defaults.

- Added flat query params for filtering and sorting. Instead of `{ 'q[name_cont]': 'shirt' }`, you can now write `{ name_cont: 'shirt', sort: 'price asc' }`. The SDK transforms these to Ransack format automatically. Old `q[...]` syntax still works for backward compatibility.

- Removed `StorePost` and `StorePostCategory` types and Zod schemas. Posts feature has been extracted to the `spree_posts` extension.

## 0.6.0

### Minor Changes

- Add `metadata` support to Store API — Stripe-style write-only key-value storage

  - Add `CreateCartParams` with optional `metadata` for setting metadata on cart creation
  - Add `metadata` parameter to `AddLineItemParams` for setting metadata when adding items to cart
  - Add `metadata` parameter to `UpdateLineItemParams` for updating line item metadata (merge semantics)
  - Add `metadata` parameter to `UpdateOrderParams` for updating order metadata (merge semantics)
  - Make `quantity` optional in `UpdateLineItemParams` (can now update metadata without changing quantity)
  - **Breaking:** `cart.create()` signature changed from `(options?)` to `(params?, options?)` — first argument is now optional `CreateCartParams`
  - Remove `public_metadata` from `StorePaymentSource` type and Zod schema

- Remove deprecated fields from `StoreStore` type — these are now managed through Markets and dedicated API endpoints

  - Remove `default_currency` — use `store.currencies.list()` or the `X-Spree-Country` header for automatic currency resolution
  - Remove `default_locale` — use `store.locales.list()` or the `X-Spree-Country` header for automatic locale resolution
  - Remove `default` — internal flag, not useful for storefront clients
  - Remove `supported_currencies` — use `store.currencies.list()` instead
  - Remove `supported_locales` — use `store.locales.list()` instead
  - Remove `default_country_iso` — use `store.countries.list()` instead

### Patch Changes

- Added missing types and zod files

## 0.5.0

### Minor Changes

- Replace markets API with flat countries, currencies, and locales endpoints

  - Remove `store.markets` (list, get, resolve, countries) methods
  - Add `store.countries` (list, get) — each country includes `currency` and `default_locale` from its market
  - Add `store.currencies` (list) — supported currencies derived from markets
  - Add `store.locales` (list) — supported locales derived from markets
  - Add `StoreCurrency` and `StoreLocale` types
  - Update `StoreCountry` type with `currency` and `default_locale` fields
  - Remove `StoreMarket` type

### Patch Changes

- Add currency attribute to StoreLineItem type and Zod schema

## 0.4.0

### Minor Changes

- **Breaking:** Replace `store.countries` with `store.markets` — Markets bundle geography (zone), currency, and locale into a single entity for multi-region commerce
  - `store.countries.list()` → `store.markets.countries.list(marketId)` (countries are now scoped to a market)
  - `store.countries.get(iso)` → `store.markets.countries.get(marketId, iso)`
  - New `store.markets.list()` — list all markets with nested countries (for country/currency switcher)
  - New `store.markets.get(id)` — get a single market by prefixed ID
  - New `store.markets.resolve(countryIso)` — resolve which market a country belongs to
- Add `country` option to `RequestOptions` — sends `X-Spree-Country` header for automatic market resolution (currency, locale, tax zone)
- Add `StoreMarket` type and `StoreMarketSchema` Zod schema
- **Breaking:** Remove `default_currency` and `default_locale` from `StoreCountry` type and Zod schema (these were misleading ISO3166 values, not store config)

## 0.3.1

### Patch Changes

- Add `download_url` field to `StoreDigitalLink` type — digital links on line items now include a ready-to-use download URL. The endpoint no longer requires API key authentication; the token in the URL is the sole authentication mechanism.

## 0.3.0

### Minor Changes

- **Breaking:** Restructure Store API endpoints for Cart, Checkout & Orders
  - Cart creation moved from `POST /orders` to `POST /cart` — use `client.cart.create()` instead of `client.orders.create()`
  - Customer order history moved from `GET /orders` to `GET /customer/orders` — use `client.customer.orders.list()` instead of `client.orders.list()`
  - `orders.create()` removed — use `cart.create()` instead
  - `orders.list()` removed — use `customer.orders.list()` instead
  - Orders namespace now focuses on individual order management and checkout: `get`, `update`, `next`, `advance`, `complete`, plus nested resources (lineItems, payments, shipments, etc.)
- Add `customer.orders.list()` method for fetching authenticated customer's order history
- Add Payment Setup Sessions support: `client.customer.paymentSetupSessions` with `create`, `get`, and `complete` methods for saving payment methods for future use

## 0.2.5

### Patch Changes

- Add currency attribute to StoreLineItem type and Zod schema

## 0.2.4

### Patch Changes

- Add payment source to `StorePayment` type — payments now include `source_type` (`'credit_card' | 'store_credit' | 'payment_source' | null`) and `source` (polymorphic union of `StoreCreditCard | StoreStoreCredit | StorePaymentSource | null`) for frontend payment source display. Add new `StorePaymentSource` and `StoreStoreCredit` types.

## 0.2.3

### Patch Changes

- Add `gateway_payment_profile_id` to `StoreCreditCard` type — exposes the Stripe PaymentMethod ID (`pm_xxx`) needed for saved card checkout flows
- `getCart()` now clears stale cart token when the backend returns 404 (e.g., after order completion)

## 0.2.2

### Patch Changes

- All cart/checkout mutations (line items create/update/delete, shipments update) now return the updated `StoreOrder` with recalculated totals, matching the industry standard
- `StoreOrder` type: all associations (`line_items`, `shipments`, `payments`, `bill_address`, `ship_address`, `order_promotions`) are now always included — no longer require `?includes=` param

## 0.2.1

### Patch Changes

- Add Payment Sessions support: `client.orders.paymentSessions` with `create`, `get`, `update`, and `complete` methods. Add `session_required` field to `StorePaymentMethod` type. Add `StorePaymentSession`, `CreatePaymentSessionParams`, `UpdatePaymentSessionParams`, and `CompletePaymentSessionParams` types.

## 0.2.0

### Minor Changes

- Restructure SDK to support dual API namespaces: `client.*` (Store API) and `client.admin.*` (Admin API)

### Internal

- Extract request infrastructure into `request.ts` with `createRequestFn()` factory
- Split monolithic `client.ts` into `store-client.ts`, `admin-client.ts`, and composed `client.ts`
- Add `StoreClient` and `AdminClient` exports

## 0.1.8

### Patch Changes

- Add addresses.markAsDefault() method to set a customer address as default billing or shipping

## 0.1.7

### Patch Changes

- Add password, password_confirmation, accepts_email_marketing, and phone to customer.update() params type

## 0.1.6

### Patch Changes

- Add digital_links to StoreLineItem type and zod schema, exposing digital download metadata (filename, content_type, access status) on line items

## 0.1.5

### Patch Changes

- Rename StoreUser/AdminUser types to StoreCustomer/AdminCustomer to align with industry naming conventions and avoid future AdminUser model conflict

## 0.1.4

### Patch Changes

- Fix automated release with npm Trusted Publishing

## 0.1.3

### Patch Changes

- Fix release workflow for npm Trusted Publishing (OIDC)

## 0.1.2

### Patch Changes

- Fix release workflow for npm Trusted Publishing

## 0.1.1

### Patch Changes

- Fix package license to MIT

- First public release with basic Product Catalog features, Customer account, Cart and Checkout
