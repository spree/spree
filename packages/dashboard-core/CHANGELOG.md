# @spree/dashboard-core

## 1.0.0-beta.2

## 1.0.0-beta.1

### Major Changes

- [#14458](https://github.com/spree/spree/pull/14458) [`da49f27`](https://github.com/spree/spree/commit/da49f27a5da1e40dbd4ce0901f8d4b21573d98df) Thanks [@mad-eel](https://github.com/mad-eel)! - Renamed stock items to stock levels.

  Spree 6.0 renames `Spree::StockItem` to `Spree::StockLevel`, and the admin API and SDK follow. There is no compatibility shim on the client side, so update your code before upgrading:

  - `client.stockItems` is now `client.stockLevels`, and it calls `/stock_levels` instead of `/stock_items`.
  - The `StockItem` type is now `StockLevel`, and `StockItemUpdateParams` is now `StockLevelUpdateParams`.
  - `StockLevelUpdateParams` also gains `reason`, which labels a count correction in the stock history.
  - `client.stockMovements` is new, and reads the typed stock history behind those levels.
  - A variant's `stock_items` array is now `stock_levels`, on both reads and writes.
  - `Subject.StockItem` is now `Subject.StockLevel` in `@spree/dashboard-core`. The old name stays as a deprecated alias for one release.
  - Prefixed ids change from `si_…` to `sl_…`. Ids you stored earlier no longer resolve.

  Webhook endpoints keep working: Spree publishes both `stock_level.*` and the older `stock_item.*` events for one release, so existing subscriptions keep firing. The dashboard's event picker now offers the `stock_level` names, and shows any `stock_item` subscription you already have under its Custom section. Move your subscriptions over before Spree 6.1, when the old names stop being published.

### Minor Changes

- [#14410](https://github.com/spree/spree/pull/14410) [`fdd88eb`](https://github.com/spree/spree/commit/fdd88eb3d2d7ac36a710a2af38593a8f4c83f2bf) Thanks [@mad-eel](https://github.com/mad-eel)! - Add dashboard pages for business customers and tax configuration.

  Companies get a list and a detail page with their branches, tax registration
  and exemption certificates; a branch has its own page listing the buyers
  authorised to purchase for it. Customers gain the same tax registration panel
  on their profile. Tax rates get a settings page, and a market can now name the
  tax engine that prices it — showing what that engine cannot handle, so a
  merchant learns about a gap while configuring rather than from a tax bill.

  The admin SDK gains the customer tax-identifier endpoints and `tax_provider`
  on market params.

- [#14591](https://github.com/spree/spree/pull/14591) [`8e5dc20`](https://github.com/spree/spree/commit/8e5dc20147ff24f53dd73b506c3f06a074d3d302) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Volume pricing: quantity breaks, percentage tiers and a price-list CSV.

  A price list can now carry a ladder per variant — a unit price from each
  quantity up — edited as tier rows in the price spreadsheet, and a catalog's
  percentage adjustment can step by quantity too. The catalog's price column
  shows how many tiers a variant carries, with the ladder on hover and a note
  that fixed tiers set the price regardless of the percentage.

  A price list's prices can be exported and imported as CSV, one rung per row
  keyed by SKU, from the list's own page and from the catalog that owns it.
  The import merges: rows in the file are written, a blank price removes that
  rung, and rungs the file does not mention are left alone. The admin SDK's
  price, price list and import types carry the new fields, and the import
  create call accepts the price list to merge into.

### Patch Changes

- [#14521](https://github.com/spree/spree/pull/14521) [`9cee487`](https://github.com/spree/spree/commit/9cee487fdce34c5f2ec873fc1d965196bd716663) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - New address forms pre-select the store's default country.

  The Admin store payload now includes `default_country_code` (the same country the default market already answers). The shared address dialog uses it for new records and leaves an existing address's country alone.

- [#14632](https://github.com/spree/spree/pull/14632) [`67594a5`](https://github.com/spree/spree/commit/67594a56921fbc5d584b371ede94b0b83f2035ea) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Country pickers load the country list once per page and reuse it.

  The list is reference data and does not change at runtime, so later address fields and country selects no longer call the API again.

- [#14413](https://github.com/spree/spree/pull/14413) [`99573b0`](https://github.com/spree/spree/commit/99573b0c717225e652e6d449b4b85f1e10f3600b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Edit the admin profile in a dialog opened from the user menu instead of a settings page. The `/settings/profile` route is removed; `TopBar` takes an `onEditProfile` handler and hides the menu item when none is supplied.

- [#14456](https://github.com/spree/spree/pull/14456) [`3a1ac28`](https://github.com/spree/spree/commit/3a1ac2851a59cf0e498af27a60e70caac3a5788e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fix an endless reload when a store sets a non-English admin language.

  i18next was initialized with the stored language but only the English bundle, so it resolved the language to the fallback and reported English no matter what was stored. The store-default reconciler compares those two values to decide whether the page needs reloading, saw a permanent mismatch, and reloaded on every boot — each reload rotating a refresh token until the API's rate limit stopped it.

  Every bundle is now registered when i18next starts, so the stored language resolves to itself and the reconciler reloads only when the language genuinely changes.

- [#14378](https://github.com/spree/spree/pull/14378) [`027ed08`](https://github.com/spree/spree/commit/027ed08056df9608554c80e343cdf24d6699d9f5) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Redesign the user dropdown's theme and language controls into a compact "Preferences" section: theme is now a segmented control (System / Light / Dark) and language is a select-style pill.

- [#14637](https://github.com/spree/spree/pull/14637) [`9b8a7d5`](https://github.com/spree/spree/commit/9b8a7d57967ec31659959547555dde6780e8ef10) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Keep list and quote toolbar buttons working after the TipTap 3.31 pin. Two copies of prosemirror-model made wrap throw; pinning one version (and deduping it in the Vite plugin) restores the stock TipTap commands. Enter still persists as its own paragraph.

- [#14635](https://github.com/spree/spree/pull/14635) [`496431d`](https://github.com/spree/spree/commit/496431d8e902269b8a5b05c9f2393eafc7e6b78b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added a settings overview page to the seller panel, matching the operator dashboard's card grid of reachable settings areas.

- [#14514](https://github.com/spree/spree/pull/14514) [`3473696`](https://github.com/spree/spree/commit/3473696bb08408addca8ef4665748c694b64b6d1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fix the filter panel crashing in the seller panel. `TableToolbar`, `ResourceCombobox` and `MediaPickerSheet` required a `StoreProvider` to scope their query keys, so opening a filter panel in a panel that has no store — the seller panel, whose tenant is a seller — threw "useStore must be used within a StoreProvider". They now scope by tenant, which is the store in the operator's dashboard and the seller in the seller panel, so cached results can no longer be shared between two sellers of the same store either.

- [#14594](https://github.com/spree/spree/pull/14594) [`4156d50`](https://github.com/spree/spree/commit/4156d50a142497858377e3159a1c2c28182cb978) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Stop the translations editor marking itself dirty on open, and refresh the translations page after a save or a catalog edit.

  The rich-text cell was treating TipTap's mount-time paragraph wrap as an unsaved change against descriptions stored as plain text. Translation queries now share one cache prefix so saving a translation, editing the source record, or importing a translations CSV invalidates the coverage grid instead of leaving it stale.

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
