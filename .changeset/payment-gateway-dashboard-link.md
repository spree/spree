---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Admin API payments now include `gateway_dashboard_payment_url`, a link to the payment in the payment provider's own dashboard. On the order page, each payment's menu shows a "View at {payment method}" link when the provider offers one, so staff can look up the full payment details there.
