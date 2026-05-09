---
'@spree/admin-sdk': minor
---

Store credit category lookups + richer store credit payloads.

- New `client.storeCreditCategories` accessor with `list / get`. Backed by `/api/v3/admin/store_credit_categories`. Read-only — categories are configured at the store level and used to classify issued store credits ("Goodwill", "Refund", "Gift Card", etc.). Ransack filtering supported (e.g. `q[name_cont]`).
- New `StoreCreditCategory` type exported from the package: `{ id, name, non_expiring, created_at, updated_at }`. `non_expiring` reflects whether the category name appears in `Spree::Config[:non_expiring_credit_types]`.
- The admin `StoreCredit` shape now includes `category_id`, `category_name`, and `memo`. `category_id` round-trips with the categories endpoint above; `category_name` is delegated from the associated category for display without an extra fetch; `memo` is the merchant-visible note set when the credit was issued.
- The existing `client.customers.storeCredits.{create,update}` endpoints have not changed shape — `category_id` and `memo` were already accepted on write; this release only surfaces them on read.
