---
"@spree/dashboard": patch
"@spree/dashboard-core": patch
---

Added a "no store access" screen for admins who sign in without a role on any store, replacing the sign-in redirect loop they hit before. Hosts can replace the screen by registering on the new `no_store_access` slot (`NO_STORE_ACCESS_SLOT` and `NoStoreAccessSlotContext` from `@spree/dashboard-core`).
