# @spree/dashboard-core

## 0.13.1

### Patch Changes

- [#14353](https://github.com/spree/spree/pull/14353) [`8bf0dd0`](https://github.com/spree/spree/commit/8bf0dd070c9369549c54a9233bca97111d7aff11) Thanks [@ifizza](https://github.com/ifizza)! - Searchable and sortable custom fields now appear as first-class product table columns. Definitions can be marked searchable/sortable from the definition form, and the new `metafieldColumns` prop on `ResourceTable` merges them into the column selector, the Sort dropdown, and the filter panel — with operators matching each field type. `ColumnDef` gains an `expand` field so a visible column can declare the association the list request must expand.

- [#14363](https://github.com/spree/spree/pull/14363) [`705e515`](https://github.com/spree/spree/commit/705e515ac881d071f45c768359380bd0ea5d23bd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - **Breaking (Admin API):** `type` on imports and exports is now the API shorthand (`"products"`, `"customers"`, `"product_translations"`, `"orders"`, `"gift_cards"`, `"coupon_codes"`, `"newsletter_subscribers"`) instead of the Ruby class name (`"Spree::Imports::Products"`). `ImportType` and `ExportType` are typed accordingly.

  Creating an import or export accepts either form, so a `type` read back from the API round-trips. Ransack filters (`type_eq`) are unaffected — they match the database column and still take the class name.

  Polymorphic type fields follow the same convention: `owner_type` on imports and `item_type` on import rows now return `"store"` / `"product"` rather than `"Spree::Store"` / `"Spree::Product"`.

- [#14363](https://github.com/spree/spree/pull/14363) [`705e515`](https://github.com/spree/spree/commit/705e515ac881d071f45c768359380bd0ea5d23bd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The CSV import sheet now offers a downloadable example file alongside the existing (headers-only) template, so you can see a populated CSV before preparing your own — or import it as-is. The examples are Spree's own sample data, the same files `rake spree:load_sample_data` uses, served through `GET /api/v3/admin/imports/example` and pinned to the installed Spree version so they always match your import schema. Import types with no example file simply omit the link.

- [#14357](https://github.com/spree/spree/pull/14357) [`f811d1e`](https://github.com/spree/spree/commit/f811d1ee5f604e24f86aa59be3317f87627fe3c7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The top-bar "View store" link is now only shown when the store has a storefront URL configured (`preferred_storefront_url`), and the sidebar store switcher is a real switcher: it lists every store the signed-in admin can access and navigates between store dashboards, rendering a plain header (no dropdown) for single-store admins. The switcher trigger also gains a localized accessible name.

## 0.13.0

### Minor Changes

- [#14342](https://github.com/spree/spree/pull/14342) [`202d846`](https://github.com/spree/spree/commit/202d846374270c75e19b23cea5498ea559577f67) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Add per-channel order routing rule management. `@spree/admin-sdk` gains `channels.orderRoutingRules.{list,get,create,update,delete}` (nested under `/channels/:channel_id/order_routing_rules`) plus `orderRoutingRules.types()` for rule-kind discovery; the admin `Store` type now exposes `preferred_order_routing_strategy`. The dashboard's channel edit sheet embeds a routing-rules editor — drag-to-reorder priority, per-rule active toggles, an "Add rule" picker fed by the types endpoint (offering only kinds not yet on the channel; rule kinds are unique per channel), and schema-driven preference forms for rule kinds that declare preferences. The editor renders only when the channel's effective routing strategy is Rules. `Subject.OrderRoutingRule` is available for permission checks.

- [#14341](https://github.com/spree/spree/pull/14341) [`dc33237`](https://github.com/spree/spree/commit/dc332372b918ffeb92252c33372a1d71a221a7d4) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Improve editing of quantity-bounded price rules. A blank upper-bound preference (`max_quantity`, `max_uses`, `maximum_amount`, …) now shows "Unlimited" instead of an empty required-looking field across every preferences form. The Volume price rule gains a dedicated editor that renders minimum quantity before maximum, so a case-pack minimum reads in a natural order.

## 0.12.0

## 0.10.2

### Patch Changes

- Fix the collapsed icon sidebar leaking a nav item's label when the item carries a badge. The collapse rule hid only the last `span` of the menu button, and a trailing badge took that slot — the label stayed visible and wrapped, breaking the collapsed layout. Both the label and badge are now hidden explicitly in collapsed icon mode.
