---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Added `taxExemptionReasons`, the store's own list of reasons a business can give for buying without tax, with list, get, create, update and delete. Each reason has a `code` that tax exemption certificates record and the tax engine receives. `taxProviders.list()` is now typed (`TaxProviderOption`) and says which exemption reason codes each engine reads. The dashboard manages the reasons under Settings → Reasons, and the certificate form offers them.
