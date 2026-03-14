---
"@spree/next": patch
---

Allow `getCart()` to accept an optional `explicitCartId` parameter. When provided, fetches that specific cart directly by ID instead of reading from cookies. Needed for the confirm-payment flow where the cart ID is known from the URL but cookies may have been cleared.
