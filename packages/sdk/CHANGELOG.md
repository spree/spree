# @spree/sdk

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

- All cart/checkout mutations (line items create/update/delete, shipments update) now return the updated `StoreOrder` with recalculated totals, matching the industry standard (Shopify, Medusa, Saleor)
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
