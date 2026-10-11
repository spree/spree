---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
---

Money is a decimal string written to its currency's decimals, and Admin and Seller writes take money and rates only as decimal strings. Added `sumMoney`, `subtractMoney`, `multiplyMoney`, `negateMoney`, `compareMoney`, `isZeroMoney`, `isDecimalString` and `decimalPlaces` for exact arithmetic on those strings. Currencies carry `decimal_places`; prices no longer carry `amount_in_cents` or `compare_at_amount_in_cents`; tax rates read and write `rate` and `rate_percent` instead of `amount` and `amount_percentage`.
