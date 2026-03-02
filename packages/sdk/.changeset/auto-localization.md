---
"@spree/sdk": patch
---

Added client-level locale, currency, and country defaults. Set them at initialization (`createSpreeClient({ locale: 'fr', currency: 'EUR', country: 'FR' })`) or update later with `client.setLocale()`, `client.setCurrency()`, `client.setCountry()`. Per-request options still override defaults.
