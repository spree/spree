---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Admin API payments now include `avs_risky` and `cvv_risky`, and can expand `capture_events`, each capture of the money the payment authorized. On the order page, a payment whose card failed the issuer's checks is flagged, and each payment's menu opens a details dialog with the address and security code check results and the list of captures.
