---
"@spree/dashboard-core": patch
---

Projects upgrading from an older Admin SDK no longer keep a version the dashboard can't build against. `@spree/dashboard-core` now requires at least the `@spree/admin-sdk` and `@spree/dashboard-ui` versions it was released with, so the package manager upgrades them instead of keeping an older copy from the lockfile.
