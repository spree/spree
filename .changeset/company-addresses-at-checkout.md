---
"@spree/sdk": minor
"@spree/admin-sdk": minor
"@spree/dashboard": minor
"@spree/dashboard-ui": minor
---

Company members can now pick their company's addresses when choosing where an order goes. Picking a company site at checkout used to be dropped without an error, because the cart only ever looked in the buyer's own address book. A new `GET /store/carts/:id/addresses` returns everything a cart may be shipped or billed to — the buyer's book plus the company's sites and the ones it inherits — and `client.carts.addresses.list()` reaches it. Every `Address` now carries the `owner` it is filed under (`null` for an address in no book, such as the copy a placed order keeps), so a picker can label the two books without working out which company the purchase is for. On the Admin API this `owner` object replaces the separate `owner_id` and `owner_type` fields. Unlike the other cart endpoints this one needs a signed-in customer: it answers with the account's address books rather than the cart's own contents. Staff get the same reach: a company's sites are selectable when creating an order, and "use default addresses" takes the company's defaults for a company order. On a division's page, addresses inherited from the companies above it are labelled with their owner and cannot be edited there.
