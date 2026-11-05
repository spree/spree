---
"@spree/cli": patch
---

`spree add klaviyo` now pins `spree_klaviyo` to the project's Spree version, since Klaviyo ships with Spree from 6.0. Before, it resolved to the 1.x gem, which does not run on Spree 6.
