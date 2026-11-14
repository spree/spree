---
"@spree/dashboard-sentry": patch
"@spree/dashboard-core": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

Added `@spree/dashboard-sentry`, which reports admin dashboard and seller panel errors to Sentry: call `initDashboardSentry({ dsn })` in the app's entry module, with any other Sentry browser option. Plugins can now receive the errors the panels' error screens catch through `errorReporters` in `defineDashboardPlugin`, and mount session-wide components in the new `app.root` slot, which both panels render. The seller panel now shows the same error screen with a retry button as the admin dashboard instead of the router's bare fallback, and `RouteErrorBoundary` takes an `onCatch` callback.
