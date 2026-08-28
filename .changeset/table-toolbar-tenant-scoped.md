---
"@spree/dashboard-core": patch
---

Fix the filter panel crashing in the seller panel. `TableToolbar`, `ResourceCombobox` and `MediaPickerSheet` required a `StoreProvider` to scope their query keys, so opening a filter panel in a panel that has no store — the seller panel, whose tenant is a seller — threw "useStore must be used within a StoreProvider". They now scope by tenant, which is the store in the operator's dashboard and the seller in the seller panel, so cached results can no longer be shared between two sellers of the same store either.
