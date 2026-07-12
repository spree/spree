---
"@spree/admin-sdk": patch
---

`ExportCreateParams` accepts an optional `results_url` (validated against the store's allowed origins) — the export-done email uses it as its download button target instead of relying on the legacy Rails admin's routes.
