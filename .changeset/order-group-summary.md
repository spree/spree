---
"@spree/sdk": minor
"@spree/admin-sdk": minor
---

`orders.get` now returns `Order | OrderGroup`. Called with the id of the cart a checkout was placed from, it returns the whole purchase: one order, or, when the checkout reached several sellers, the order group holding one order per seller. Narrow the result with `isOrderGroup` before reading order-only fields such as `items`. An order group now carries the same money summary as an order (delivery, discount, tax, fee, gift card and store credit totals, the amount still due) and its payments.

`store_credit_total` on carts, orders and order groups no longer includes what a gift card paid. That amount is reported only in `gift_card_total`, so a summary that shows both rows no longer deducts it twice. `amount_due` no longer subtracts store credit that has already been captured.
