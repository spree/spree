---
"@spree/seller-sdk": patch
---

`StockLocation` now includes `pickup_enabled`, `pickup_stock_policy`, `admin_name`, `backorderable_default` and `propagate_all_variants`, which the Seller API now returns. Before, a client that read a location and saved it back reset these settings to their defaults.
