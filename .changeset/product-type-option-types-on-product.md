---
"@spree/dashboard-core": patch
"@spree/dashboard": patch
"@spree/seller-dashboard": patch
---

The product page's Variants card now shows the option types a product got from its product type. A product made from a type that adds, say, Color has Color as soon as it is created, but no variant uses it yet, and the card only looked at the variants, so it showed just "Add option" and the default variant. A saved product's own option types that no variant uses yet are now offered as empty rows, ready for their values, in both the admin and the seller panel.
