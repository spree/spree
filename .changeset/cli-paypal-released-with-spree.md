---
"@spree/cli": patch
---

`spree add paypal` now pins `spree_paypal_checkout` to the project's Spree version, since PayPal ships with Spree from 6.0. Before, it resolved to the 0.x gem, which does not run on Spree 6.
