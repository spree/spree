---
"@spree/admin-sdk": patch
---

Fulfillment `tracking` now accepts a full `https://` tracking link — the API serves it back as `tracking_url` unchanged instead of templating it into the delivery method's tracking URL. Useful when an external system (3PL, courier API) provides the complete link.
