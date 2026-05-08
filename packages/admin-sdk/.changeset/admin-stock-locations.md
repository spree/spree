---
'@spree/admin-sdk': minor
---

Stock location management.

- New `client.stockLocations` accessor with `list / get / create / update / delete`. Backed by `/api/v3/admin/stock_locations`. Listing supports the standard Ransack filters (`name_cont`, `active_eq`, `kind_eq`, `pickup_enabled_eq`, etc.) plus default ordering by `default desc, name asc` so the default location surfaces first.
- New params types: `StockLocationCreateParams`, `StockLocationUpdateParams`. Address fields use `country_iso` (ISO-2 code, e.g. `'US'`) and `state_abbr` — same convention as `Spree::Address`. `Spree::Country` and `Spree::State` are global and don't expose prefixed IDs, so ISO/abbr are the canonical opaque handles.
- The `StockLocation` entity gains the 6.0 fulfillment-and-delivery columns: `kind` (`'warehouse' | 'store' | 'fulfillment_center'`, open string — plugins can register custom kinds), `pickup_enabled`, `pickup_stock_policy` (`'local'` keeps stock at the location only; `'any'` allows transfer-in / ship-to-store), `pickup_ready_in_minutes`, and `pickup_instructions`. These are the storefront-facing fields the upcoming pickup-fulfillment flow surfaces at checkout. See `docs/plans/6.0-fulfillment-and-delivery.md` for the wider context.
- Admin serializer now also exposes `admin_name`, `address2`, `state_name`, `phone`, `company`, plus `created_at` / `updated_at`.
