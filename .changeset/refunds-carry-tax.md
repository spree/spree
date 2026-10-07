---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
---

Returns, claims and exchanges now give back the tax the customer paid. Return lines carry `included_tax_total`, `additional_tax_total`, `tax_total` and `refund_amount` (tax included), and returns carry `refund_tax_total`. On a store whose prices include VAT, a return line's `pre_tax_amount` now reads the price before tax rather than the gross price. Claim and exchange lines carry the tax on each half, tax lines name the return, claim or exchange line they belong to and whether they are a `credit`, Admin refunds carry `tax_amount`, and Seller order line items carry `additional_tax_total`. Fees gain the `exchange` kind.
