---
"@spree/sdk": patch
---

Stop sending `orderToken` as a URL query parameter. The order token is now sent exclusively via the `x-spree-order-token` header, keeping auth tokens out of URLs (server logs, browser history, referrer headers).
