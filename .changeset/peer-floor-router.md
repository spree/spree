---
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

The `@tanstack/react-router` peer range starts at 1.170.46, the oldest version the dashboards type check against. Apps on 1.170.45 already failed to type check, so no working setup is excluded.
