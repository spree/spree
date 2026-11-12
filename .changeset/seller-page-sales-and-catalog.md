---
"@spree/admin-sdk": patch
"@spree/dashboard": patch
"@spree/dashboard-core": patch
"@spree/dashboard-ui": patch
---

A seller now carries `products_count_by_status`, how many of their products are in each status, read in the same query as `products_count`. The seller page shows the seller's last 30 days of net sales and commission, their orders with those still to fulfill, and their products, approving or sending back those in review in place. The onboarding checklist moves to the sidebar, and the products list can be filtered to products in review or sent back.

`@spree/dashboard-core`'s `ResourceTable` takes `onSearchChange`, and `useEmbeddedTableSearch` supplies it, so a record page can embed a list table whose state stays out of the URL. `hiddenColumns` leaves columns out of a table, and `framed` draws it as a card holding its toolbar and pagination, with no pinned header.

`@spree/dashboard-ui`'s `CollapsibleContent` now slides and fades open and closed, with its chevrons turning in step, and stays instant under reduced motion.
