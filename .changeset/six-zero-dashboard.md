---
'@spree/dashboard': patch
---

Dashboard features from the 6.0 core rewrite:

- Delivery method editor: Conditions section (eligibility rules), pickup stock-location picker, calculator preferences through the shared preferences form.
- Order page: discount code card (apply a typed code or pick a coupon promotion; pending codes show when they'll take effect) and a live computed-amount preview for percent manual discounts.
- Webhook endpoint event catalog lists `order.placed`; delivery zones request members via `expand`.
