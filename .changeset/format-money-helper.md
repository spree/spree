---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": patch
---

Added `formatMoney(amount, currency, locale?, { unitPrice? })`, which formats a decimal-string amount in its currency and the reader's language with the currency's own decimal places, without passing it through a JavaScript number. The dashboard now uses the SDK's copy.
