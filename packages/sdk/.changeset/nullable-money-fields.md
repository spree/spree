---
"@spree/sdk": minor
---

Money fields are now typed `string | null` across Cart, Order, LineItem, Payment, Fulfillment, GiftCard, and Discount (Zod schemas accept `null` accordingly). On a gated channel (`prices_hidden`), the Store API returns `null` for every monetary amount — including those on records nested inside a cart or order — so anonymous visitors cannot recover hidden prices. Handle `null` before formatting or doing arithmetic on these fields.
