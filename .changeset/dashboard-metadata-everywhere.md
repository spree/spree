---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
---

The admin dashboard now shows metadata on every record that has it. Detail pages end their main column with Custom fields and Metadata, both folded to a header that counts what they hold, so the page leads with the record itself. Records listed inside another page (payments, fulfillments, returns, claims, exchanges, store credits, shipping labels, discounts, fees and seller requirement submissions) get a "View metadata" item in their row menu, and settings records edited in a side panel show it in a collapsed section; both appear only when the record has metadata.
