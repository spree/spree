---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
---

Fixed the Edit prices grid on a market with a comma decimal saving a typed `19.50` as 1950. A period followed by anything other than three digits is now read as a decimal point, and the grid shows exactly the amount it will save.
