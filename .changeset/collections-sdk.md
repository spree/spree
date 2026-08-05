---
'@spree/admin-sdk': patch
'@spree/sdk': minor
---

Collections reach both SDKs.

`@spree/sdk` (storefront):

- `collections.list()` / `collections.get(idOrPermalink)` — the flat, merchandising-driven groupings ("Summer Sale", "New Arrivals"), whether membership is curated by hand or maintained from rules.
- `collections.products.list(idOrPermalink, params)` — a collection's product listing page. Takes the same filters and sorts as `products.list`, and when `sort` is omitted the collection's own `sort_order` applies, so a shopper sees the ordering the merchant chose (including their manual arrangement).
- `in_collection` on `ProductListParams`, for composing a collection filter into a wider product query.

`@spree/admin-sdk` (back office):

- `collections` CRUD, with reordering as a plain 1-based `position` on update rather than a separate action — collections are a flat list. Nested `collections.products` covers membership, ordering and `reposition`, plus custom fields and translations.
- `collectionRules.types()` enumerates the registered rule kinds, so a rule a plugin registers shows up without an SDK release.
- `products.bulkAddToCollections` / `bulkRemoveFromCollections`, and `collection_ids` on product create/update.
- `rules` on a collection is expand-gated (`?expand=rules`), matching `custom_fields` — a listing no longer ships every collection's full rule set.
- `hide_from_nav` is gone from the category params. Nothing read it.
