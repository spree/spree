---
"@spree/cli": patch
---

`spree add klaviyo` now requires `spree_klaviyo` at the project's Spree version or newer, since Klaviyo ships with Spree from 6.0. Before, it resolved to the 1.x gem, which does not run on Spree 6.
