---
"@spree/dashboard-core": patch
---

The Variants card (`VariantsSection`) now shows the option types a product got from its product type. It takes the product's own option type ids (`productOptionTypeIds`), fetches those option types by id, and offers each one no variant uses yet as an empty row, ready for its values. Before, it only looked at the variants' option values, so a product made from a type that adds Color showed just "Add option" and the default variant.
