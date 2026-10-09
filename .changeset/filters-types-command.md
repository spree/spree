---
"@spree/cli": minor
---

Added `spree filters types`, which writes TypeScript declarations for an app's own list filters and sort fields from its running backend (or from `bin/rails spree:api:filter_tables` output with `--from`), so the SDKs accept and autocomplete them.
