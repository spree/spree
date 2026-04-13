---
"@spree/sdk": patch
---

Add `total`, `display_total`, `additional_tax_total`, `display_additional_tax_total`, `included_tax_total`, and `display_included_tax_total` to `DeliveryRate` type. Add `total`, `display_total`, `discount_total`, `display_discount_total`, `additional_tax_total`, `display_additional_tax_total`, `included_tax_total`, `display_included_tax_total`, `tax_total`, and `display_tax_total` to `Fulfillment` type. These fields expose post-discount pricing and tax breakdowns that were previously missing from the Store API, fixing incorrect shipping rate display when free shipping promotions are applied.
