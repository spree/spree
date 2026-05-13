---
'@spree/sdk': patch
---

Expose `Product.meta_title` in the Store API.

`meta_title` is a storefront SEO field (used in `<title>` tags) — previously it was only on the Admin product serializer. Now serialized on the Store `Product` type as `meta_title: string | null` so storefronts can render it without a second admin call.
