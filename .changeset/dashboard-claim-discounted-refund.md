---
"@spree/dashboard": patch
"@spree/dashboard-ui": patch
"@spree/seller-dashboard": patch
---

The New claim dialog now pre-fills each line's refund with what the customer paid for those items after discounts, instead of their list price, which the claim would refuse to refund on a discounted order. The amount follows the claimed quantity until the merchant types one of their own. Code that builds the dialog's lines itself passes `discountedAmount` (the line's `discounted_amount`) in place of `price`, which `ClaimableLine` no longer accepts.
