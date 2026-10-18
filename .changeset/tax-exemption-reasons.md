---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

Added `taxExemptionReasons`, the store's own list of reasons a business can give for buying without tax, with list, get, create, update and delete. Each reason has a `code` the tax engine receives. Tax exemption certificates now point at a reason with `tax_exemption_reason_id` instead of recording `reason_code`, and can expand `tax_exemption_reason`. `taxProviders.list()` is now typed (`TaxProviderOption`) and says which exemption reason codes each engine reads. The dashboard gains one Settings → Taxes page with tabs for tax categories, tax rates and exemption reasons, which also shows the tax service each market uses; the certificate form offers the store's reasons.
