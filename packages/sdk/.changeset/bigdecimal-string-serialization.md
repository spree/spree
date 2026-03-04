---
"@spree/sdk": patch
---

Monetary amount types (`cost`, `amount`, `amount_used`, `amount_authorized`, `amount_remaining`, `cost_price`) changed from `number` to `string` in `StoreShippingRate`, `StoreGiftCard`, `AdminProduct`, and `AdminVariant` types. This follows the Stripe convention of serializing financial values as strings to preserve decimal precision across JSON parsers.
