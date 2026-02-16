# @spree/next

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
