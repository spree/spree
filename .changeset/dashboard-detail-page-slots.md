---
"@spree/dashboard": minor
"@spree/seller-dashboard": minor
---

Plugins can now add cards to more detail pages. The admin dashboard has new slots on the seller payout, catalog, price list, promotion, purchase order, stock transfer and webhook endpoint pages, and the catalog, price list and promotion pages now save extension fields bound with `useHostForm()` with the page's own Save button. The seller panel has new slots on its product, order, payout and profile pages, and its product page saves extension fields the same way, under the form key `seller.product`. The slots catalog lists every slot and the context it receives.
