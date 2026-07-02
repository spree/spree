---
"@spree/admin-sdk": patch
---

Regenerated types: fixes `created_at`/`updated_at` on Country, State, and other resources previously typed `unknown` to `string`. Admin money fields remain non-nullable — storefront price gating never applies to the Admin API.
