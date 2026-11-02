---
"@spree/dashboard": patch
---

Plugins can build their own order pages from the order page's building blocks, exported from `@spree/dashboard/orders`: `useOrderItemsEditor` (staged line editing with negotiated draft prices and a one-transaction save), `OrderEditItemsTable`, `AddLineItemDialog`, `OrderTotalsCard`, `useOrder`, the customer, logistics, purchase order, discounts and notes cards, and the new-order page's company and customer pickers. The order edit page now runs on the same hook.
