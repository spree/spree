---
"@spree/dashboard-core": patch
---

The tiers editor for the tiered percent and tiered flat rate calculators now reads and writes tiers as a list of `{ threshold, value }` entries, the shape Spree 6.0 stores them in. It still reads the old hash keyed by threshold, so a calculator the upgrade has not converted yet opens correctly.
