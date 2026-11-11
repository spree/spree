---
"@spree/admin-sdk": patch
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Updating a seller takes `returns_address`, written inline like `billing_address`. It is saved onto the seller's returns stock location, or a new one for a seller who has none, so the seller page edits it in place instead of opening the stock location. `@spree/dashboard-core` exports `EditStockLocationSheet`, so a record page can open a location's editor without leaving the page.
