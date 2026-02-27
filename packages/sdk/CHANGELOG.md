# @spree/sdk

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
  - Cart creation moved from `POST /orders` to `POST /cart` — use `client.store.cart.create()` instead of `client.store.orders.create()`
  - Customer order history moved from `GET /orders` to `GET /customer/orders` — use `client.store.customer.orders.list()` instead of `client.store.orders.list()`
  - `orders.create()` removed — use `cart.create()` instead
  - `orders.list()` removed — use `customer.orders.list()` instead
  - Orders namespace now focuses on individual order management and checkout: `get`, `update`, `next`, `advance`, `complete`, plus nested resources (lineItems, payments, shipments, etc.)
- Add `customer.orders.list()` method for fetching authenticated customer's order history
- Add Payment Setup Sessions support: `client.store.customer.paymentSetupSessions` with `create`, `get`, and `complete` methods for saving payment methods for future use

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

- Add Payment Sessions support: `client.store.orders.paymentSessions` with `create`, `get`, `update`, and `complete` methods. Add `session_required` field to `StorePaymentMethod` type. Add `StorePaymentSession`, `CreatePaymentSessionParams`, `UpdatePaymentSessionParams`, and `CompletePaymentSessionParams` types.

## 0.2.0

### Minor Changes

- Restructure SDK to support dual API namespaces: `client.store.*` (Store API) and `client.admin.*` (Admin API)

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
