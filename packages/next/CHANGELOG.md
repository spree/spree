# @spree/next

## 0.6.3

### Patch Changes

- Add Markets data functions and update country types

  - Add `listMarkets()`, `getMarket(id)`, `resolveMarket(country)`, `listMarketCountries(marketId)`, `getMarketCountry(marketId, iso)` data functions
  - Export `StoreMarket` type
  - **Breaking:** `StoreCountry` no longer includes `currency`, `default_locale`, `supported_locales` — use the markets API or `?include=market` on countries

- Updated dependencies:
  - @spree/sdk@0.6.3

## 0.6.2

### Patch Changes

- Added `quick_checkout` attribute support for Address via updated SDK dependency

- Bump SDK dependency for `state_lock_version` response type support.

## 0.6.1

### Patch Changes

- Added automatic localization. Data functions now auto-read locale and country from cookies when no explicit options are provided. New exports: `setLocale` server action for country/language switchers, `createSpreeMiddleware` (from `@spree/next/middleware`) for URL-based routing with geo-detection. Added `country` to `SpreeNextOptions` and `countryCookieName`, `localeCookieName`, `defaultCountry` to `SpreeNextConfig`.

- Updated data function params to use typed flat query params (`ProductListParams`, `TaxonListParams`, `OrderListParams`) instead of `Record<string, unknown>`.

- Removed Posts and PostCategory references. Posts feature has been extracted to the `spree_posts` extension.

## 0.6.0

### Minor Changes

- Add `metadata` support to cart actions

  - `getOrCreateCart()` now accepts optional `metadata` parameter for setting metadata on new carts
  - `addItem()` now accepts optional `metadata` parameter: `addItem(variantId, quantity, metadata)`
  - **Breaking:** `updateItem()` signature changed from `(lineItemId, quantity)` to `(lineItemId, { quantity?, metadata? })` — pass an object with `quantity` and/or `metadata` keys
  - Updated `@spree/sdk` peer dependency

### Patch Changes

- Update `StoreStore` type — fields removed upstream in `@spree/sdk` (`default_currency`, `default_locale`, `default`, `supported_currencies`, `supported_locales`, `default_country_iso`) are no longer part of the store response. Use dedicated `listCurrencies`, `listLocales`, and `listCountries` functions instead.

- Updated dependencies:
  - @spree/sdk@0.6.0

## 0.5.0

### Minor Changes

- Replace market data functions with flat countries, currencies, and locales

  - Remove `listMarkets`, `getMarket`, `resolveMarket`, `listMarketCountries`, `getMarketCountry`
  - Add `listCountries`, `getCountry` — countries with currency and locale from markets
  - Add `listCurrencies` — supported currencies
  - Add `listLocales` — supported locales
  - Export `StoreCurrency` and `StoreLocale` types, remove `StoreMarket`

- Updated dependencies:
  - @spree/sdk@0.5.0

## 0.4.0

### Minor Changes

- **Breaking:** Replace country functions with market functions to match @spree/sdk 0.4.0 Markets API
  - `listCountries()` / `getCountry()` removed
  - New `listMarkets()` — list all markets with nested countries (for country/currency switcher)
  - New `getMarket(id)` — get a single market
  - New `resolveMarket(countryIso)` — resolve country to market
  - New `listMarketCountries(marketId)` — list countries in a market (for checkout address forms)
  - New `getMarketCountry(marketId, iso)` — get a country with states (for address validation)
- Re-export `StoreMarket` type from `@spree/sdk`
- Bump `@spree/sdk` peer dependency to `>=0.4.0`

## 0.3.1

### Patch Changes

- Re-export `StoreDigitalLink` type from `@spree/sdk` — digital links now include a `download_url` field for direct file downloads without API key authentication
- Bump `@spree/sdk` dependency for `StoreDigitalLink.download_url` field

## 0.3.0

### Minor Changes

- **Breaking:** Update to match @spree/sdk 0.3.0 Store API restructure
  - `listOrders()` now calls `GET /customer/orders` (was `GET /orders`) — requires authenticated customer
  - `getOrCreateCart()` now creates carts via `POST /cart` (was `POST /orders`)
- Bump `@spree/sdk` peer dependency to `>=0.3.0`

## 0.2.4

### Patch Changes

- Bump @spree/sdk dependency for StoreLineItem currency field

- Update type references from StoreUser to StoreCustomer following @spree/sdk rename

## 0.2.3

### Patch Changes

- Update `StoreCreditCard` type with `gateway_payment_profile_id` field (from @spree/sdk 0.2.3)
- `getCart()` now clears stale cart token when the backend returns 404 (e.g., after order completion), preventing the storefront from showing a completed order in the cart

## 0.2.2

### Patch Changes

- All cart/checkout mutations (`addItem`, `updateItem`, `removeItem`, `selectShippingRate`) now return the updated `StoreOrder` with recalculated totals, eliminating the need for follow-up fetches
- `StoreOrder` now always includes all associations (line items, shipments, payments, addresses) — no need to pass `includes` param

## 0.2.1

### Patch Changes

- Add Payment Sessions server actions: `createPaymentSession`, `getPaymentSession`, `updatePaymentSession`, and `completePaymentSession`. Re-export `StorePaymentSession` and related param types from `@spree/sdk`.

## 0.2.0

### Minor Changes

- Restructure to match @spree/sdk dual API namespace changes
- Add payment sessions support (`createPaymentSession`, `completePaymentSession`)
- Add checkout `complete()` action

## 0.1.2

### Patch Changes

- Update type references from StoreUser to StoreCustomer following @spree/sdk rename

## 0.1.1

### Patch Changes

- Add changelog and changeset support for automated npm releases

## 0.1.0

### Minor Changes

- First public release with Next.js server actions, caching, and cookie-based auth for Spree Commerce
