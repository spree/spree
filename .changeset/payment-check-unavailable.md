---
"@spree/dashboard": patch
---

A payment's details dialog shows "Not available" instead of "Did not pass" when the address or security code check was not run — the issuer's system was unavailable, the card or its issuer does not support it, or the street line was not verified. The payments table's warning reads "Card checks not available" in that case. A result where the details did not match still shows "Did not pass" and "Failed card checks".
