---
'@spree/cli': minor
---

`spree upgrade` now moves the dashboard packages and the Admin and Seller SDKs to the Spree version. From Spree 6.0 these packages share the version of the Spree gems, and a range on an older line such as `^1.0.0-rc.7` would never reach it on its own. For a storefront on an older `@spree/sdk` line, the upgrade names the exact range to move to.
