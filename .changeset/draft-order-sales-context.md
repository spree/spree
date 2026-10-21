---
"@spree/admin-sdk": minor
"@spree/dashboard": minor
---

New draft orders take a market, sales channel, currency and locale, chosen before any item is added. A market fixes the currency and the locales on offer. The item search on a new or existing draft order lists only what the buyer can be sold on that channel, priced as they would pay in that market; `variants.list()` accepts `order_id`, or `market_id`, `channel_id`, `customer_id`, `company_id` and `currency` for an order not yet created. `order_id` cannot be combined with the other fields, and `currency` on its own also narrows the list. Order creation refuses items the buyer cannot order on the channel, and picks a market selling the requested currency when none is named. Changing any of these after items are picked asks before removing them.
