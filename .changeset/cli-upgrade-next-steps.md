---
"@spree/cli": patch
---

`spree upgrade` no longer reminds you to schedule `Spree::StockReservations::ExpireJob`, a Spree 5.5 step that every 5.6 installation has already done. The "Next steps" panel now points you at your scheduled jobs and behavior changes in the upgrade guide and links to a page that exists. `spree upgrade --plan` now lists the same data backfills a real run executes after the Spree gems are bumped, instead of nothing.
