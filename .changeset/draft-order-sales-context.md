---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

New draft orders take a market, sales channel, currency and language, chosen before any item is added. A market fixes the currency and the languages on offer. The item search on a new or existing draft order lists only what the buyer can be sold on that channel, priced as they would pay in that market; `variants.list()` accepts `order_id`, or `market_id`, `channel_id`, `customer_id`, `company_id` and `currency` for an order not yet created. Changing any of these after items are picked asks before removing them.
