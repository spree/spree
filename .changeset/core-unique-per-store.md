---
'@spree/cli': patch
---

Option types are now owned by a store, so two stores can each define their own `size`. Existing option types are assigned to the default store by migration.
