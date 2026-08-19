---
'@spree/admin-sdk': major
'@spree/dashboard': major
'@spree/dashboard-core': major
---

Renamed stock items to stock levels.

Spree 6.0 renames `Spree::StockItem` to `Spree::StockLevel`, and the admin API and SDK follow. There is no compatibility shim on the client side, so update your code before upgrading:

- `client.stockItems` is now `client.stockLevels`, and it calls `/stock_levels` instead of `/stock_items`.
- The `StockItem` type is now `StockLevel`, and `StockItemUpdateParams` is now `StockLevelUpdateParams`.
- `StockLevelUpdateParams` also gains `reason`, which labels a count correction in the stock history.
- A variant's `stock_items` array is now `stock_levels`, on both reads and writes.
- `Subject.StockItem` is now `Subject.StockLevel` in `@spree/dashboard-core`. The old name stays as a deprecated alias for one release.
- Prefixed ids change from `si_…` to `sl_…`. Ids you stored earlier no longer resolve.

Webhook endpoints keep working: Spree publishes both `stock_level.*` and the older `stock_item.*` events for one release, so existing subscriptions keep firing. The dashboard's event picker now offers the `stock_level` names, and shows any `stock_item` subscription you already have under its Custom section. Move your subscriptions over before Spree 6.1, when the old names stop being published.
