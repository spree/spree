---
'@spree/cli': minor
---

`spree upgrade` now moves the dashboard packages and the Admin and Seller SDKs to the Spree version. From Spree 6.0 these packages share the version of the Spree gems, and a range on an older line such as `^1.0.0-rc.7` would never reach it on its own. A package pinned to an exact version moves to the Spree version and stays pinned; before, `update` left it on the old release while the server moved on. The upgrade then dedupes each app, so a dependency the new release pins, such as `@codemirror/view`, isn't left installed twice and failing type checks. Yarn 2 and later is now also recognised from the `packageManager` field. For a storefront on an older `@spree/sdk` line, the upgrade names the exact range to move to.
