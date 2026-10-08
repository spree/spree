---
"@spree/admin-sdk": minor
"@spree/seller-sdk": minor
"@spree/dashboard": minor
---

Changed every type value the Admin and Seller APIs send or accept to a short name instead of a Ruby class name: delivery method, digital asset, payout, tax and pickup point providers (`manual`, `internal`, `system`, `file`), order routing strategies (`rules`), custom field definition `resource_type` (`product`, `category`), tag `taggable_type`, the owner and originator types on addresses, refunds and media usage, and type filters such as `type_eq` and `receivable_type_eq`. Removed `integration_class` from the provider listings and the custom field `type` field from the Admin API (use `field_type`; the Store API keeps the deprecated field), and corrected the shipping label `owner_type` type to `'fulfillment' | 'return'`.
