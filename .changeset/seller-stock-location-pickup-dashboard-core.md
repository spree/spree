---
"@spree/dashboard-core": patch
---

Editing a stock location in the seller panel no longer turns customer pickup off. `PanelStockLocation` now requires the pickup setting, pickup stock policy, internal name, backorderable default and "propagate all variants" setting, so the shared form opens with the stored values instead of saving defaults over them.
