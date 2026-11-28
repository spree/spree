---
"@spree/admin-sdk": minor
---

Gift cards can be sold as products. `Product` and `Variant` carry `gift_card`, which product create and update accept. Line items return the gift card `recipient` and the `gift_cards` they issued. `GiftCard` returns the `line_item_id` and `issuing_order_id` that bought it, and can be filtered by `line_item_id`. `Store` adds `gift_card_default_validity_days`, which store update accepts.
