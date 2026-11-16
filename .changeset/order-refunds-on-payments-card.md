---
"@spree/admin-sdk": patch
"@spree/dashboard": patch
---

The order page now shows refunds. Each refund, whether it came from a return or from the order, is listed on the Payments card under the payment it went back to, with its reason, date and amount. The summary adds a "Refunded" line. Before this, the card's badge read "Partially refunded" but the refund appeared nowhere.

The Admin API's order now has `refunds_total` and an expandable `refunds` list (`?expand=refunds`), and each admin refund carries `refund_reason_name`. `@spree/admin-sdk`'s `Order` and `Refund` types include them.
