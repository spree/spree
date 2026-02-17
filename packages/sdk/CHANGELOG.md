# @spree/sdk

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
