---
"@spree/sdk": minor
---

**Breaking:** Store API endpoint changes requiring backend >= 5.4.0.rc2:

- **Default address:** Removed `markAsDefault()` method. Use `is_default_billing` / `is_default_shipping` booleans on `create()` and `update()` instead (Medusa/Vendure pattern)
- **Removed redundant endpoints:** `carts.paymentMethods.list()`, `carts.payments.list()`, `carts.payments.get()`, `carts.fulfillments.list()` — payment methods, payments, and fulfillments are included in the cart response
- **`AddressParams`** now includes `is_default_billing` and `is_default_shipping` fields
- **Address response** now includes `is_default_billing` and `is_default_shipping` fields
- **Cart/Order response** now includes `store_credit_total`, `gift_card_total`, `covered_by_store_credit`, and `gift_card` association
- **Customer response** now includes `available_store_credit_total`
- **New endpoint:** `customer.storeCredits.list()` — list store credits for the authenticated customer
