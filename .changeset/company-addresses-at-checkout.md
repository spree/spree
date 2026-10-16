---
"@spree/sdk": minor
"@spree/dashboard": minor
"@spree/dashboard-ui": minor
---

Company members can now pick their company's addresses when choosing where an order goes. Picking a company site at checkout used to be dropped without an error, because the cart only ever looked in the buyer's own address book. A new `GET /store/carts/:id/addresses` returns everything a cart may be shipped or billed to — the buyer's book plus the company's sites and the ones it inherits — and `client.carts.addresses.list()` reaches it. Staff get the same reach: a company's sites are selectable when creating an order, and "use default addresses" takes the company's defaults for a company order.
