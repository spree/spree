---
"@spree/admin-sdk": minor
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
"@spree/seller-dashboard": patch
---

Admin returns carry `display_refunded_total`. A refunded return's card in the dashboard and the seller panel now shows what was actually refunded instead of what the return was worth, and names both when less went back, for example "Refunded $25.00 of $30.26".
