---
"@spree/dashboard-sentry": patch
"@spree/dashboard-core": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Added `@spree/dashboard-sentry`, a plugin that reports admin dashboard and seller panel errors to Sentry once installed and given a `VITE_SENTRY_DSN`. Plugins can now receive the errors the panels' error screens catch through `onError` in `defineDashboardPlugin`, and mount session-wide components in the new `app.root` slot, which both panels render. The seller panel now shows the same error screen with a retry button as the admin dashboard instead of the router's bare fallback.
