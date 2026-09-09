---
"@spree/sdk": patch
"@spree/admin-sdk": patch
"@spree/seller-sdk": patch
---

Preserve HTTP error statuses when a server returns an empty, non-JSON, or malformed error body. Avoid treating these responses as network failures, and allow admin and seller session recovery to handle unauthorized responses.
