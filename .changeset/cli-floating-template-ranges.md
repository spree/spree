---
"@spree/cli": patch
---

The embedded dashboard-starter template now floats its `@spree/*` dependency ranges to the newest published release (floored at the versions the template was built against) instead of pinning the minor — scaffolded apps pick up new dashboard releases without waiting for a CLI release. The template also slims to `@spree/dashboard` + `@spree/admin-sdk`: `defineDashboardPlugin` is re-exported from `@spree/dashboard`, and `@spree/dashboard-core` / `@spree/dashboard-ui` are added by the app only when building custom pages.
