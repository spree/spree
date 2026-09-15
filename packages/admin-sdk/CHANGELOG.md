# @spree/admin-sdk

## 1.0.0

### Major Changes

- [#14442](https://github.com/spree/spree/pull/14442) [`4df88ac`](https://github.com/spree/spree/commit/4df88ac684688e65623703544686c6043a8ed816) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Rename the geography fields to `country_code` and `state_code` across the v3 API, replacing `country_iso` and `state_abbr`. Addresses, stock locations, delivery zone members, markets, tax rates and tax exemption certificates all use the new names, on read and on write. Markets rename their list of countries from `country_isos` to `country_codes`.

  Addresses keep `country_iso` and `state_abbr` as deprecated read fields and accepted write names for one release, so existing storefronts keep working; both are removed in 6.1. Every other resource moves outright.

- [#14445](https://github.com/spree/spree/pull/14445) [`6d4fe64`](https://github.com/spree/spree/commit/6d4fe64a1444bc42338942025a4ed1d5788cb9d7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - First-run setup asks which country the store sells from.

  `completeSetup` now requires `country_code` and accepts optional `locale` and `currency`. Both default to the country's own — its first official language and its currency — so a store's money and geography agree unless you say otherwise. An unrecognised currency is now rejected rather than quietly ignored.

  `login`, `acceptInvitation`, `resetPassword` and `completeSetup` on the dashboard auth context now resolve with the session they establish, so callers can read the signed-in user without waiting for provider state.

  A new `auth.setupCountries()` lists the countries a store can be set up in, each with the currency and official languages derived from it. Like the rest of the setup flow it needs no credentials, and stops answering once an admin account exists.

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

- [#14461](https://github.com/spree/spree/pull/14461) [`32d4db9`](https://github.com/spree/spree/commit/32d4db9cdb027d9fb59e18807b26c0aa6ceb48ad) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Store credits no longer carry a category. `client.storeCreditCategories` and the `StoreCreditCategory` type are removed, `category_id` is no longer accepted or returned on customer store credits, and the dashboard's issue/edit store credit dialogs drop the category picker — the memo is the place to record why a credit was issued.

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

- [#14430](https://github.com/spree/spree/pull/14430) [`9a4eb46`](https://github.com/spree/spree/commit/9a4eb466c2698d15d735c06e4b5faf984bb63dd2) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Order numbers are now configurable from the dashboard.

  **Settings → Store → Order numbers** controls how document numbers are shaped: the numbering format (sequential or random), the order number prefix and suffix, and the value the sequence starts at. A live preview shows what the next number will look like.

  Sequential numbering is the new default — orders count up from 1001 (`R1001`, `R1002`) instead of carrying nine random digits. Merchants who would rather not disclose their order volume can switch the format back to random. Either way, changes apply to future orders only; numbers already issued never change.

  `StoreUpdateParams` and the `Store` type gain `preferred_document_number_format`, `preferred_order_number_prefix`, `preferred_order_number_suffix` and `preferred_order_number_sequence_start`.

- [#14489](https://github.com/spree/spree/pull/14489) [`889a8cf`](https://github.com/spree/spree/commit/889a8cfd24443710cfff5a7d30fbe83d65148cac) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Media library. Every image and video in a store now lives in one place under Products → Media: browse it, search by file name, filter by type or by whether a file is in use, and upload files before deciding where they go. Picking a file from the library reuses it rather than copying it, so the same photo on three products is one file in storage.

  The library is reachable from everywhere media is set. The product gallery gains "Add from library", category, collection and seller image fields gain "Choose from library", and the rich text editor can embed an image in a description for the first time. Category and collection images now appear in the library too, so a file uploaded there can be reused anywhere else.

  Every file shows where it is used before it is deleted, and deleting one that is still in use removes it from those places once the merchant confirms.

  New in `@spree/admin-sdk`: the `media` resource (`list`, `get`, `create`, `update`, `delete`, `usage`), `source_media_id` on product media creation for reuse, and `signed_id`, `embed_url`, `filename`, `content_type`, `byte_size` and `attached` on the admin media payload.

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

- [#14457](https://github.com/spree/spree/pull/14457) [`676aa0d`](https://github.com/spree/spree/commit/676aa0dee62a26944cb0a2c83273b149ba922b8a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Product galleries can hold video.

  A media item now says what it is through `media_type`. `video` is a file you upload and serve yourself; `external_video` is a YouTube or Vimeo link. Both sit in the same gallery as images and reorder alongside them.

  Spree reads the link when it is saved and rejects anything it cannot embed, so the media object comes back carrying `video_provider`, `video_embed_url`, `video_url` and `poster_url` — a storefront embeds a video without parsing links itself. A video's sized URLs resolve to its poster, so a gallery written for images still renders the right still.

  `MediaCreateParams` and `MediaUpdateParams` accept `media_type`, `external_video_url`, `poster_signed_id` and the focal point. The `type` parameter, which named an internal Ruby class, is gone — `media_type` replaces it.

  A video carries a **poster** — the still shown before it plays. Upload one with `poster_signed_id`, or leave it off and a YouTube link falls back to the provider's own image. Spree does not extract a frame from an uploaded file, so hosted video and Vimeo links want a poster.

  In the dashboard, video files upload through the same drop zone as images, an "Add video link" button takes a YouTube or Vimeo URL, and the media editor plays the video back and takes a poster the merchant uploads. The editor also gains a focal-point picker: click the spot on an image that must stay in frame when a storefront crops it.

  Choosing which variants a media item represents happens in one place — the media editor on the product. The unmounted variant-side gallery picker has been removed; it was a second way to edit the same thing.

- [#14462](https://github.com/spree/spree/pull/14462) [`abc6e22`](https://github.com/spree/spree/commit/abc6e22cb60ea305a83583ded0b999458b2c9cbd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Which address a sale's tax is computed from is now a store setting rather than a global one. `preferred_tax_using_ship_address` can be read and written through the Admin API, and merchants can change it under Settings → Store in the Payments card. The default is unchanged: tax follows the shipping address.

### Patch Changes

- [#14521](https://github.com/spree/spree/pull/14521) [`9cee487`](https://github.com/spree/spree/commit/9cee487fdce34c5f2ec873fc1d965196bd716663) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - New address forms pre-select the store's default country.

  The Admin store payload now includes `default_country_code` (the same country the default market already answers). The shared address dialog uses it for new records and leaves an existing address's country alone.

- [#14394](https://github.com/spree/spree/pull/14394) [`a8b11ec`](https://github.com/spree/spree/commit/a8b11ecb409a04c8d48ec6d64892ffa3bd6dacf7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Collections reach both SDKs.

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

- [#14417](https://github.com/spree/spree/pull/14417) [`7e35951`](https://github.com/spree/spree/commit/7e35951361a6cee7b735640b0228710928719fee) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Rich-text fields read as plain text plus HTML.

  Spree 6.0 stores rich text as sanitized HTML in plain text columns instead of Action Text. The write params are unchanged — `description` and `internal_note` still take the value, and that value is HTML.

  What changed is the read side:

  - `internal_note_html` is now readable on `Order`, and `internal_note` (plain text) on `Customer`. Previously the order serializer returned only plain text and the customer serializer only HTML; both now return the pair.
  - `description` returns tag-stripped plain text, with the markup under `description_html`. Hydrate an editor from `description_html`, not `description`.

  The field stores HTML, so send markup — a plain-text value with newlines in it renders as one run-on line.

- [#14376](https://github.com/spree/spree/pull/14376) [`a52a6da`](https://github.com/spree/spree/commit/a52a6da42f5c456e889f8bba12ee7194934289b1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Admin API additions from the 6.0 core rewrite:

  - `deliveryMethods.rules` CRUD and `deliveryMethods.ruleTypes()` — delivery method eligibility rules (item total, weight).
  - `orders.discountCodes.create/delete` — apply and remove coupon codes on draft orders with the storefront's pending semantics.
  - `expand=cart` on orders returns the originating cart (new admin `Cart` type); the embedded promotion summaries moved from the `discounts` key to `applied_promotions` (the `discounts` name stays reserved for the typed money rows at `/orders/:id/discounts`).
  - Delivery methods accept `stock_location_ids` for pickup; delivery zones, delivery methods and stock locations are store-scoped.
  - `Order` gains `cart_id` and `coupon_code`; `DeliveryZone.members` requires `expand=members`.

- [#14593](https://github.com/spree/spree/pull/14593) [`0f22450`](https://github.com/spree/spree/commit/0f224508b3d270aaa9899a508966a27c37f873ed) Thanks [@Hemang-ai](https://github.com/Hemang-ai)! - Preserve HTTP error statuses when a server returns an empty, non-JSON, or malformed error body. Avoid treating these responses as network failures, and allow admin and seller session recovery to handle unauthorized responses.

## 0.8.1

### Patch Changes

- [#14353](https://github.com/spree/spree/pull/14353) [`8bf0dd0`](https://github.com/spree/spree/commit/8bf0dd070c9369549c54a9233bca97111d7aff11) Thanks [@ifizza](https://github.com/ifizza)! - Custom field definitions now support storefront search, sort, and filtering: `CustomFieldDefinition` exposes `searchable`, `sortable`, and `filter_key`, and create/update params accept `searchable` (short*text, long_text, number) and `sortable` (short_text, number). Product list requests accept the resulting `cf*\*`keys as both`sort`values and Ransack filter predicates (e.g.`q[cf_custom_material_i_cont]`).

- [#14357](https://github.com/spree/spree/pull/14357) [`f811d1e`](https://github.com/spree/spree/commit/f811d1ee5f604e24f86aa59be3317f87627fe3c7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `AdminUser` now includes a `stores` array — every store the user holds a role on (`{ id, name, code }` with prefixed IDs), powering the dashboard store switcher.

- [#14363](https://github.com/spree/spree/pull/14363) [`705e515`](https://github.com/spree/spree/commit/705e515ac881d071f45c768359380bd0ea5d23bd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - **Breaking (Admin API):** `type` on imports and exports is now the API shorthand (`"products"`, `"customers"`, `"product_translations"`, `"orders"`, `"gift_cards"`, `"coupon_codes"`, `"newsletter_subscribers"`) instead of the Ruby class name (`"Spree::Imports::Products"`). `ImportType` and `ExportType` are typed accordingly.

  Creating an import or export accepts either form, so a `type` read back from the API round-trips. Ransack filters (`type_eq`) are unaffected — they match the database column and still take the class name.

  Polymorphic type fields follow the same convention: `owner_type` on imports and `item_type` on import rows now return `"store"` / `"product"` rather than `"Spree::Store"` / `"Spree::Product"`.

## 0.8.0

### Minor Changes

- [#14342](https://github.com/spree/spree/pull/14342) [`202d846`](https://github.com/spree/spree/commit/202d846374270c75e19b23cea5498ea559577f67) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Add per-channel order routing rule management. `@spree/admin-sdk` gains `channels.orderRoutingRules.{list,get,create,update,delete}` (nested under `/channels/:channel_id/order_routing_rules`) plus `orderRoutingRules.types()` for rule-kind discovery; the admin `Store` type now exposes `preferred_order_routing_strategy`. The dashboard's channel edit sheet embeds a routing-rules editor — drag-to-reorder priority, per-rule active toggles, an "Add rule" picker fed by the types endpoint (offering only kinds not yet on the channel; rule kinds are unique per channel), and schema-driven preference forms for rule kinds that declare preferences. The editor renders only when the channel's effective routing strategy is Rules. `Subject.OrderRoutingRule` is available for permission checks.

## 0.7.0

### Minor Changes

- Support channel binding on publishable API keys. `apiKeys.create()` accepts an optional `channel_id`, and `ApiKey` now carries `channel_id`. A bound key always resolves its channel server-side and rejects requests naming a different one; the binding is create-only and immutable. Omit `channel_id` for a store-wide key.

## 0.6.1

### Patch Changes

- `Customer` supports the new `newsletter_subscriber` expand — pass `expand: ['newsletter_subscriber']` to `customers.get`/`customers.list` to include the customer's store-scoped newsletter subscription.

## 0.6.0

This is the Admin API surface the 5.6 React Dashboard consumes — hosts installing `@spree/dashboard@0.10.x` from the registry need this version; 0.5.0 lacks exports the dashboard imports.

### Minor Changes

- Add asynchronous CSV imports. `client.imports.create({ type, attachment })` queues an import from a direct-uploaded CSV (pass the `signed_id` from `client.directUploads.create()`); the response is in the `mapping` state and carries the type's `schema_fields`, the file's `csv_headers`, a `sample_row`, and auto-assigned column `mappings`. Adjust mappings if needed and call `client.imports.completeMapping(id, { mappings })` to start background processing, then poll `client.imports.get(id)` — `rows_count`, `completed_rows_count`, and `failed_rows_count` drive progress until the terminal `completed`/`failed` status. Failed rows (with the raw CSV `data` and per-row `validation_errors`) are listed via `client.imports.rows.list(id, { status_eq: 'failed' })` and can be re-processed with `client.imports.retryFailedRows(id)`. Pass an optional `results_url` on create (validated against the store's allowed origins) and the import-done email links back to your admin's imports view with `?import=<id>` appended. New `Import`, `ImportRow`, `ImportMapping`, `ImportType`, `ImportCreateParams`, and `ImportCompleteMappingParams` types describe these shapes.

- Add translation management for translatable resources. `client.translatableResources.list()` discovers every translatable resource type, its translatable fields, and whether each one exposes a dedicated read route (`readable`); `client.locales.list()` returns the locales a merchant can translate content into for the current store. Per-resource reads are available via `client.products.translations.get(id)` and `client.optionTypes.translations.get(id)`, each returning the full locale × field matrix plus any nested translatable children (e.g. an option type's option values) in one request. All writes go through `client.translations.batch(entries)` — a single atomic endpoint that upserts translations across many records of any registered type, so an option type and all its option values can be translated in one save. New `Locale`, `TranslatableResource`, `TranslatableField`, `ResourceTranslations`, `ResourceTranslationsNode`, and `TranslationBatchEntry` types describe these shapes.

- Add `orders.fulfillments.create` for manually registering fulfillments on completed orders (`POST /orders/:order_id/fulfillments`). Supports external carrier / 3PL sync: pick the stock location, carrier (`delivery_method_id`), tracking number, and line item quantities (`items`, omitted = everything not yet shipped), and pass `status: 'shipped'` to register an already-shipped fulfillment. Adds the `FulfillmentCreateParams` type. `FulfillmentUpdateParams.selected_delivery_rate_id` is now honored by the Admin API (previously the server expected a different field name and ignored it).

- `orders.fulfillments.create` now accepts an optional `cost` (explicit shipping cost, e.g. the 3PL price — frozen exactly on `status: 'shipped'` registrations; note it changes the order total and payment state). When `delivery_method_id` is omitted, the new fulfillment now inherits the delivery method and cost of the source fulfillment(s) it fully drains instead of defaulting to the lowest-cost rate.

- Add pre-order management to the Admin API. `Variant` now exposes the editable `preorderable` flag, `preorder_ships_at` (the "ships by" date), and `backorder_limit` (the universal oversell cap — units sellable beyond available stock as backorders or pre-orders; `null` = unlimited), alongside the computed `preorder` state; `Product` and `LineItem` gain `preorder` + `preorder_ships_at`. `ProductVariantInput`, `VariantCreateParams`, and `VariantUpdateParams` accept `preorderable`, `preorder_ships_at`, and `backorder_limit`, so a variant can be flagged for pre-order and capped in a single write.

- Expose customer group membership on the Customer resource. `Customer.customer_group_ids` now always returns the prefixed group IDs a customer belongs to (the full `customer_groups` objects remain available via `expand`), and `CustomerCreateParams`/`CustomerUpdateParams` accept `customer_group_ids` to replace a customer's group membership in a single `PATCH /customers/{id}` — no separate add/remove calls needed.

- Add self-service profile updates for the authenticated admin. `client.me.update(params)` (`PATCH /me`) lets the signed-in admin change their own `selected_locale` (admin UI display language), `first_name`, and `last_name` without going through the store-scoped staff-management endpoint. The `MeResponse.user` shape now includes `selected_locale`, and a new `MeUpdateParams` type describes the writable fields.

- Expose `Store.available_locales` — the full canonical set of locale codes a merchant may translate content into, independent of the store's currently-configured `supported_locales`. Lets locale pickers offer any supported locale instead of only ones already in use.

- Expose the store-wide gated storefront defaults on the Store resource. `Store.preferred_storefront_access` (`public`, `prices_hidden`, or `login_required`) and `Store.preferred_guest_checkout` are now serialized, and `StoreUpdateParams` accepts both — letting apps read and configure the store-level fallback that channels inherit when they don't set their own posture.

### Patch Changes

- `ExportCreateParams` accepts an optional `results_url` (validated against the store's allowed origins) — the export-done email uses it as its download button target instead of relying on the legacy Rails admin's routes.

- Fulfillment `tracking` now accepts a full `https://` tracking link — the API serves it back as `tracking_url` unchanged instead of templating it into the delivery method's tracking URL. Useful when an external system (3PL, courier API) provides the complete link.

- Regenerated types: fixes `created_at`/`updated_at` on Country, State, and other resources previously typed `unknown` to `string`. Admin money fields remain non-nullable — storefront price gating never applies to the Admin API.

## 0.5.0

### Minor Changes

- Align the variant write params with the v3 API: variants are priced exclusively through the per-currency `prices` array — the legacy singular `compare_at_price` field is no longer accepted.

  **Note on bump type:** `@spree/admin-sdk` is on a 0.x version line (`next` dist-tag, Developer Preview). Per Changesets convention, breaking changes on 0.x packages bump the minor — moving to `major` would mean 1.0.0 and signal API stability we do not yet guarantee. The changes below are breaking; coordinated with the server-side change shipping in Spree 6.0.

  **Breaking changes:**

  - `VariantCreateParams` and `VariantUpdateParams` no longer accept `compare_at_price`. Set the compare-at price per currency via `prices: [{ currency, amount, compare_at_amount }]` instead.
  - `VariantCreateParams.options` is now required. The standalone `variants.create` endpoint always creates a non-master variant, which must declare at least one option pair (e.g. size + color) or creation fails with `422`.
  - `ProductCreateParams.variants` / `ProductUpdateParams.variants` now use the new `ProductVariantInput` type instead of `VariantCreateParams[]` / `VariantUpdateParams[]`. A nested variant entry keeps `options` optional: an options-less entry upserts onto the product's default variant (the simple, no-options product case).

## 0.4.0

### Minor Changes

- API key scopes are now immutable after creation. `apiKeys.update()` accepts only `name` — `ApiKeyUpdateParams` no longer includes `scopes` and now requires `name` (a breaking change to the public type). Added `apiKeys.current()` to describe the authenticating key, including its live scopes.

## 0.3.0

### Minor Changes

- Add the top-level `prices` shorthand to `ProductCreateParams`/`ProductUpdateParams` for simple (no-options) products — prices ship alongside `name`/`status` and forward to the product's sole variant, so callers don't have to construct a `variants` array. Widen the refund `amount` (`orders.refunds.create`) and `OrderCancelParams.refund_amount` to `string | number` for consistency with every other monetary field, and update examples to send amounts as strings so localized input (`"1.299,00"`) round-trips through the backend's locale-aware parsing.

## 0.2.0

### Minor Changes

- Cookie-backed admin authentication. The refresh token now lives in an `HttpOnly` signed cookie scoped to `/api/v3/admin/auth` instead of being returned in JSON; the access token is the only thing the SPA holds in memory. This eliminates the most attractive XSS target on the admin SPA and adds a real server-side logout that destroys the refresh-token row.

  CSRF protection is provided by the combination of the cookie's `SameSite` attribute and the existing `Spree::AllowedOrigin` allowlist enforced via `Rack::Cors` — no separate CSRF token is issued or required by the SDK.

  **Note on bump type:** `@spree/admin-sdk` is on a 0.x version line (`next` dist-tag, Developer Preview). Per semver §4 and Changesets convention, breaking changes on 0.x packages bump the minor — moving to `major` would mean 1.0.0 and signal API stability we do not yet guarantee. The changes below are breaking; coordinated with the server-side change shipping in Spree 5.5.

  **Breaking changes:**

  - `AuthTokens` no longer contains `refresh_token`. The shape is `{ token, user }`.
  - `client.auth.refresh()` takes no arguments — it reads the refresh-token cookie. Previously it required `{ refresh_token }` in the body.
  - New `client.auth.logout()` — POSTs to `/api/v3/admin/auth/logout`, which destroys the refresh-token row server-side and clears the auth cookie. Idempotent.
  - `createAdminClient()` now defaults to `credentials: 'include'` so cookies flow on cross-origin requests. Override via `createAdminClient({ credentials: 'omit' })` if needed.
  - The `secretKey || jwtToken` constructor guard has been relaxed: a cookie-auth SPA may start with neither and bootstrap by calling `auth.refresh()` immediately. Server-to-server callers should still pass `secretKey`.

  When using `baseUrl: ''` (e.g. with a Vite dev proxy), the SDK now resolves the relative path against `window.location.origin` so `new URL` doesn't throw.

- Admin CSV exports — bring back filtered CSV downloads of products, orders, customers, etc. that the legacy Rails admin supported.

  - New `client.exports` resource with `list / get / create / delete`.
  - New `ExportCreateParams` / `ExportType` request types and `Export` entity type.
  - `Export.download_url` is the path to a server-side download endpoint (`GET /api/v3/admin/exports/:id/download`) that 303s to a freshly-signed ActiveStorage URL — assign it to `window.location.href` to trigger the download.
  - `Export.done` flips to `true` once the background job finishes generating and attaching the CSV; clients should poll `get(id)` until then.
  - `search_params` accepts the same Ransack predicate shape (`{ name_cont, price_gt, … }`) used on list endpoints, so toolbar filter state can be forwarded as-is.

- Custom Fields CRUD API + token-based `field_type`.

  - New `client.{products,variants,orders,customers,categories,optionTypes}.customFields` accessors with `list / get / create / update / delete`.
  - New top-level `client.customFieldDefinitions` accessor with full CRUD.
  - New generic escape hatch `client.customFields(ownerType, ownerId)` for plugin-defined parents that don't have a first-class accessor.
  - `CustomField.field_type` and `CustomFieldDefinition.field_type` are now string-literal unions (`'short_text' | 'long_text' | 'rich_text' | 'number' | 'boolean' | 'json' | (string & {})`) instead of plain `string`. Built-ins narrow + autocomplete; plugin tokens still type-check.
  - `CustomField` retains the legacy `type` field (Ruby STI class name) alongside the new `field_type` token. The TypeScript type is annotated with `@deprecated` so editors surface the migration tip on hover; eslint with `no-deprecated` will flag references. Migrate to `field_type`; `type` will be removed in a future minor.
  - New `CustomFieldDefinition` type exported from the package.
  - Includes the `Spree::CustomField` / `Spree::CustomFieldDefinition` constant aliases on the server side; no naming changes to existing models or table layout.

- Sprint 3: utility CRUD writes for tax categories, stock items, stock transfers, and payment methods.

  - `client.taxCategories` gains `get / create / update / delete`. Backed by `/api/v3/admin/tax_categories`. The serializer now exposes `description` alongside `name`, `tax_code`, and `is_default`. Setting `is_default: true` on create or update auto-demotes the previous default.
  - `client.stockItems` is new with `list / get / update / delete`. Adjust `count_on_hand` and `backorderable` on existing variant/location pairings. Stock items are auto-created when a variant lands at a stock location, so there's no `create` here — use the variants and stock-locations endpoints for that flow. Filterable via Ransack on `count_on_hand`, `stock_location_id`, and `variant_id`.
  - `client.stockTransfers` is new with `list / get / create / delete`. Backed by `/api/v3/admin/stock_transfers`. The create body takes a `variants: [{ variant_id, quantity }]` array; pass `source_location_id` for a transfer between two locations or omit it to record an external seller receive at the destination. The model fans the payload out across `stock_movements` and adjusts source/destination `count_on_hand` atomically.
  - `client.paymentMethods` gains `create / update / delete / types`. The create body requires `type` (the fully-qualified STI subclass, e.g. `'Spree::PaymentMethod::Check'`); unknown types return a 422 with `unknown_payment_method_type`. New payment methods are scoped to the current store automatically. The serializer now exposes `display_on` and `position` on top of the existing `name`, `description`, `type`, `active`, and `auto_capture`. `client.paymentMethods.types()` returns the registered subclasses as `[{ type, label, description }]` so admin UIs can render a provider dropdown without hard-coding class names.

  Provider-specific configuration (Stripe API keys, PayPal credentials, etc.) is **not** part of this release — that lands with the universal preferences form in the next sprint.

- Sprint 4: full admin promotion stack — promotions, actions, rules, and coupon codes.

  - `client.promotions` is new with `list / get / create / update / delete`. Mirrors `Spree::Promotion`: `name`, `description`, `code`, `starts_at`, `expires_at`, `usage_limit`, `match_policy`, `kind` (`'coupon_code' | 'automatic'`), `multi_codes` + `number_of_codes` + `code_prefix` for batch coupon generation, `path`, `advertise`, `promotion_category_id`, and `store_ids`.

  - `client.promotions.actions` (nested) handles the STI subclass pattern: `list / get / create / update / delete` on `/promotions/:id/promotion_actions`. The create body takes a `type` (the fully-qualified subclass like `'Spree::Promotion::Actions::FreeShipping'`) plus a `preferences: { ... }` hash that round-trips through the typed setters declared on the subclass.

  - `client.promotions.rules` (nested) is the same shape for `Spree::PromotionRule` subclasses (Currency, Country, ItemTotal, Product, Taxon, etc.).

  - `client.promotions.couponCodes` (nested) is read-only — `list / get`. Coupon codes are server-generated based on the promotion's `multi_codes` settings.

  - `client.promotionActions.types()` and `client.promotionRules.types()` are top-level discovery endpoints. Each returns `{ data: ResourceTypeDefinition[] }` where each entry is `{ type, label, description, preference_schema }`. The `preference_schema` describes the configurable knobs for a given subclass — `[{ key, type, default }]` — so admin UIs can render generic configuration forms without hard-coding per-subclass field lists.

  - `client.paymentMethods.create / update` now accept an optional `preferences` hash, matching the same round-trip pattern. The serializer payload also gains `preferences` (current values) and `preference_schema` (shape).

  - New shared types: `PreferenceField`, `ResourceTypeDefinition`. The previously-shipped `PaymentMethodType` is now an alias of `ResourceTypeDefinition`.

- Staff and API key management.

  - New `client.adminUsers` accessor with `list / get / update / delete`. Listing is scoped to admin users with at least one role assignment on the current store. `delete` removes the per-store role assignment rather than deleting the global account, so the user keeps access to any other stores.
  - New `client.invitations` accessor with `list / get / create / delete / resend`. Invitations carry an `email` + prefixed `role_id`; on accept, a per-store `RoleUser` is created. `resend` issues a fresh token and re-dispatches the invitation email.
  - New `client.apiKeys` accessor with `list / get / create / update / delete / revoke`. Supports both `publishable` (storefront) and `secret` (server-to-server) keys. The plaintext token for secret keys is delivered exactly once on the create response — store it client-side immediately because subsequent reads expose only `token_prefix`. `revoke` marks the key revoked while preserving the row for audit.
  - New `client.roles` accessor with `list / get`. Read-only — used to populate the role picker on the staff invite/edit forms.
  - New `client.auth.lookupInvitation(id, token)` and `client.auth.acceptInvitation(id, token, params)`. Public (unauthenticated) endpoints that drive the SPA invitation acceptance screen — `lookup` returns the safe-to-render context (store, role, inviter, `invitee_exists`) so the page can pick between sign-in (existing account) and signup (new account); `accept` creates the user if needed, marks the invitation accepted, and issues a JWT + refresh-token cookie identical to `auth.login`.
  - `Invitation` now carries `acceptance_url` — the shareable link the SPA's "Copy invitation link" action and the invitation email both use.
  - New types: `ApiKey`, `Invitation`, `Role`, `InvitationLookup`. `AdminUser` now includes a `roles` field with the role assignments scoped to the current store.
  - New params types: `ApiKeyCreateParams`, `ApiKeyUpdateParams`, `InvitationCreateParams`, `InvitationAcceptParams`, `AdminUserUpdateParams`.

- Stock location management.

  - New `client.stockLocations` accessor with `list / get / create / update / delete`. Backed by `/api/v3/admin/stock_locations`. Listing supports the standard Ransack filters (`name_cont`, `active_eq`, `kind_eq`, `pickup_enabled_eq`, etc.) plus default ordering by `default desc, name asc` so the default location surfaces first.
  - New params types: `StockLocationCreateParams`, `StockLocationUpdateParams`. Address fields use `country_iso` (ISO-3166 alpha-2 country code, e.g. `'US'`) and `state_abbr` (state/province abbreviation, e.g. `'NY'`) — the same opaque handles used everywhere else in the API for countries and states.
  - The `StockLocation` entity gains the 6.0 fulfillment-and-delivery columns: `kind` (`'warehouse' | 'store' | 'fulfillment_center'`, open string — plugins can register custom kinds), `pickup_enabled`, `pickup_stock_policy` (`'local'` keeps stock at the location only; `'any'` allows transfer-in / ship-to-store), `pickup_ready_in_minutes`, and `pickup_instructions`. These are the storefront-facing fields the upcoming pickup-fulfillment flow surfaces at checkout. See `docs/plans/6.0-fulfillment-and-delivery.md` for the wider context.
  - Admin serializer now also exposes `admin_name`, `address2`, `state_name`, `phone`, `company`, plus `created_at` / `updated_at`.

- Store credit category lookups + richer store credit payloads.

  - New `client.storeCreditCategories` accessor with `list / get`. Backed by `/api/v3/admin/store_credit_categories`. Read-only — categories are configured at the store level and used to classify issued store credits ("Goodwill", "Refund", "Gift Card", etc.). Ransack filtering supported (e.g. `q[name_cont]`).
  - New `StoreCreditCategory` type exported from the package: `{ id, name, non_expiring, created_at, updated_at }`. `non_expiring` reflects whether the category name appears in `Spree::Config[:non_expiring_credit_types]`.
  - The admin `StoreCredit` shape now includes `category_id`, `category_name`, and `memo`. `category_id` round-trips with the categories endpoint above; `category_name` is delegated from the associated category for display without an extra fetch; `memo` is the merchant-visible note set when the credit was issued.
  - The existing `client.customers.storeCredits.{create,update}` endpoints have not changed shape — `category_id` and `memo` were already accepted on write; this release only surfaces them on read.

- Add provider-dispatched login. `client.auth.login()` now accepts third-party identity-provider payloads (e.g. `{ provider: 'okta', token: '<jwt>' }`) in addition to the existing `{ email, password }` shape — `LoginCredentials` is now a discriminated union of `EmailPasswordLogin | ProviderLogin`, both newly exported. Pairs with the server-side strategy registry at `Spree.admin_authentication_strategies`. Existing email/password calls are unchanged.

### Patch Changes

- Expose `Product.option_values` in the Admin API.

  The `Product` type now includes an optional `option_values: Array<OptionValue>` field, listing the option values that are actually in use across the product's variants — useful for rendering option pickers and variant matrices in the admin without iterating over every variant.
