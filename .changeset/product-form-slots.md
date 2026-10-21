---
"@spree/dashboard": minor
"@spree/dashboard-core": minor
"@spree/seller-dashboard": minor
---

Added product page slots for plugins: `product.form_main` at the end of the main column, `product.media.form_fields` in the media editor, `product.media.actions` in the Media card, and `product.variant.form_fields` in the variant editor, with `seller.product.*` counterparts in the seller panel. `product.form_sidebar` now also renders on the new product page, and both column slots receive `mode`. Fields on a media or variant row register under the `product.media` and `product.variant` form keys and save with the product.
