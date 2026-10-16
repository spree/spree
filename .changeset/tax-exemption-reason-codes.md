---
"@spree/admin-sdk": minor
---

Added `companies.taxExemptionCertificates.reasonCodes()`, which lists the reasons a merchant may record on a tax exemption certificate, grouped by the tax provider that understands them. Its response is typed with the new `TaxExemptionReasonCodeGroup` and `TaxExemptionReasonCode` types.
