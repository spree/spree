# @spree/dashboard

## 1.0.0-beta.8

### Patch Changes

- [#14746](https://github.com/spree/spree/pull/14746) [`3ad9173`](https://github.com/spree/spree/commit/3ad917373f1fc309d10db464dee746b7264a9818) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The setup screen no longer says an installation is already set up when it simply could not check. A rate-limited check shows "Too many attempts" and a failed one shows "Couldn't check setup", each with a retry button; "Setup is not available" now appears only when the server confirms setup is done. The setup status is also no longer re-checked every time the browser tab regains focus.

- Updated dependencies []:
  - @spree/dashboard-core@1.0.0-beta.8
  - @spree/dashboard-ui@1.0.0-beta.8

## 1.0.0-beta.7

### Patch Changes

- [`928c1ba`](https://github.com/spree/spree/commit/928c1bac9370491fa45a3a38062550b0e98cb95a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fixed the dashboard failing to start in newly created projects.

  Since 1.0.0-beta.4, a fresh project's dashboard stopped before rendering with `SyntaxError: ... does not provide an export named 'useSyncExternalStore'`. The store setup form had switched to deep imports into `@spree/dashboard-ui` and `@spree/dashboard-core`, which makes Vite handle Base UI in a way that leaves one of its dependencies unconverted. The form uses the package entry points again. Base UI returns to 1.8.0; the 1.5.0 pin in the previous release did not help.

- Updated dependencies [[`928c1ba`](https://github.com/spree/spree/commit/928c1bac9370491fa45a3a38062550b0e98cb95a)]:
  - @spree/dashboard-core@1.0.0-beta.7
  - @spree/dashboard-ui@1.0.0-beta.7

## 1.0.0-beta.6

### Patch Changes

- [`0b50f65`](https://github.com/spree/spree/commit/0b50f65410a80a30110b61fd0f13674366243f19) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Held Base UI at 1.5.0 so a scaffolded dashboard starts.

  `@base-ui/react` 1.6.0 moved to `@base-ui/utils` 0.3.x, which added a `useStore` helper importing `useSyncExternalStore` **by name** from the CommonJS `use-sync-external-store` shim. Vite converts CommonJS while prebundling an ordinary dependency, but `@spree/dashboard-ui` ships source: in the Spree monorepo it is a workspace link that Vite crawls as application source, while an installed copy lives in `node_modules` and is not crawled. That file then reaches the browser with the named CommonJS import intact and the dashboard fails with a `SyntaxError` before rendering.

  1.5.0 pins `@base-ui/utils` 0.2.9, which has no such file. The previous release pinned 1.8.0 — exact, but on the wrong side of the change — so this supersedes it.

- [`3bc3e01`](https://github.com/spree/spree/commit/3bc3e01f67d1ec7b6cd8a7f03f7b6ef24d276d5f) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Pinned every `@spree/dashboard-ui` dependency to an exact version.

  The package ships source rather than a bundle, so its dependencies are compiled into each consuming app by that app's own Vite. A floating range means a scaffolded project installs whatever those packages published most recently, not what Spree built and tested against — which is how a Base UI release that had never been tested here reached users and stopped the dashboard from starting.

  `recharts` moves to 3.10.1 as part of this: 3.8.1 pinned `reselect` 5.1.1, which published without the provenance its predecessors had, so the workspace's `no-downgrade` trust policy refuses it. 3.10.1 resolves `reselect` 5.2.0, which carries provenance again. `react-redux` is overridden to 9.3.0 for the same reason — 9.2.0 dropped the provenance 9.1.0 had, and recharts' own range accepts 9.3.0.

  Every other pin records the version already installed, so nothing else about the tree changes.

- Updated dependencies [[`0b50f65`](https://github.com/spree/spree/commit/0b50f65410a80a30110b61fd0f13674366243f19), [`3bc3e01`](https://github.com/spree/spree/commit/3bc3e01f67d1ec7b6cd8a7f03f7b6ef24d276d5f)]:
  - @spree/dashboard-ui@1.0.0-beta.6
  - @spree/dashboard-core@1.0.0-beta.6

## 1.0.0-beta.5

### Patch Changes

- [`35fb9e8`](https://github.com/spree/spree/commit/35fb9e8868718420bab03142b2d9990fefa18dc7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Pinned Base UI to an exact version so a scaffolded dashboard boots.

  `@base-ui/react` was caret-ranged, so every new project installed whatever Base UI had published most recently rather than the version Spree tested against. `@base-ui/utils` 0.3.0 added a `useStore` helper that imports `useSyncExternalStore` by name from the CommonJS `use-sync-external-store` shim. Vite converts that during prebundling for an ordinary dependency, but `@spree/dashboard-ui` ships source, so an installed copy reached the browser with the named CommonJS import intact and the dashboard failed to start with a `SyntaxError`.

  The monorepo's committed lockfile hid this — only fresh installs floated onto the newer Base UI. It is now pinned exactly, in the packages and as a workspace override, and the monorepo runs the same version a scaffold installs.

- Updated dependencies [[`35fb9e8`](https://github.com/spree/spree/commit/35fb9e8868718420bab03142b2d9990fefa18dc7)]:
  - @spree/dashboard-ui@1.0.0-beta.5
  - @spree/dashboard-core@1.0.0-beta.5

## 1.0.0-beta.4

### Minor Changes

- [#14716](https://github.com/spree/spree/pull/14716) [`9cd3d42`](https://github.com/spree/spree/commit/9cd3d42efa3aaf9297dd574a7d960f92a60b17e9) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Host apps that build their own screens on the dashboard packages can now import the sign-in building blocks directly: `@spree/dashboard/components/spree/auth-shell` (`AuthShell`), `@spree/dashboard/hooks/use-auth-providers` (`useAuthProviders`, plus `authCallbackErrorKey` for the errors the SSO callback redirects back with) and `@spree/dashboard/schemas/auth` (the auth form schemas). The `admin.fields.setup.*` translations moved to `@spree/dashboard-core`, so `StoreSetupFields` renders translated outside the full dashboard too.

### Patch Changes

- [#14730](https://github.com/spree/spree/pull/14730) [`6742c1a`](https://github.com/spree/spree/commit/6742c1a868acc124b1773be8db187c7f512aa040) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fixed the Edit prices grid on a market with a comma decimal saving a typed `19.50` as 1950. A period followed by anything other than three digits is now read as a decimal point, and the grid shows exactly the amount it will save.

- [#14717](https://github.com/spree/spree/pull/14717) [`c2d6f40`](https://github.com/spree/spree/commit/c2d6f4091dadeefc20539e20cb91b788e490d03a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `@spree/dashboard-core` now exposes `@spree/dashboard-core/client` (`adminClient`) and `@spree/dashboard-core/api-client` (`setApiClient`), so a small app that only needs the Admin API client and sign-in no longer bundles the whole framework through the package entry point. `StoreSetupFields` imports only the modules it uses, cutting a minimal app that mounts it from about 2.2 MB to 0.9 MB of JavaScript.

- [#14727](https://github.com/spree/spree/pull/14727) [`a862b80`](https://github.com/spree/spree/commit/a862b80014fc5aa8ecddca1008917eda9f17635f) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The dashboard now refers to customers by their 6.0 class name, `Spree::Customer`, instead of the pre-6.0 `Spree::User`. This fixes the Customers list's Tags filter, which always showed "No results", along with customer permission checks and customer custom fields. `client.customFields('Spree::Customer', id)` is now supported; `'Spree::User'` keeps working until 6.1.

- [#14721](https://github.com/spree/spree/pull/14721) [`5f2b412`](https://github.com/spree/spree/commit/5f2b412966a3beb29ceab3e53064e00aec5ee93a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - An exchange's replacement fulfillment, its packing slip and the Exchanges card now name the replacement product instead of the original one.

- [#14691](https://github.com/spree/spree/pull/14691) [`86d4b93`](https://github.com/spree/spree/commit/86d4b93193e9ee3537d61601a1b8f975f6cba679) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added a "no store access" screen for admins who sign in without a role on any store, replacing the sign-in redirect loop they hit before. Hosts can replace the screen by registering on the new `no_store_access` slot (`NO_STORE_ACCESS_SLOT` and `NoStoreAccessSlotContext` from `@spree/dashboard-core`).

- [#14676](https://github.com/spree/spree/pull/14676) [`854ebfe`](https://github.com/spree/spree/commit/854ebfe510cfded6d574485bb090e9a33e27e78d) Thanks [@RomanMaluf-Vaypol](https://github.com/RomanMaluf-Vaypol)! - Added a complete Spanish (mostly Rioplatense/voseo) translation bundle for the admin dashboard. The language picker now lists "Español" with every framework and page string covered — the dashboard and dashboard-core ships matching `es.json` files with full key parity against `en.json`.

- [#14736](https://github.com/spree/spree/pull/14736) [`e601826`](https://github.com/spree/spree/commit/e601826eb3cc701bc918ae7ddb9c2c52598e02d7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Invitation listings no longer include `acceptance_url`, because the link carries the token that accepts the invitation. Fetch it on demand with `invitations.acceptanceLink(id)` (and `sellers.invitations.acceptanceLink(sellerId, id)` in the Admin SDK), which needs write access. The "Copy invitation link" actions in the dashboard and the seller panel now use it.

- Updated dependencies [[`349dddf`](https://github.com/spree/spree/commit/349dddfb537dad5b82aa50a2409bd3d0d0918756), [`d065d0b`](https://github.com/spree/spree/commit/d065d0b793046cacc671f0d5297990b9ac600ab7), [`9e41f7d`](https://github.com/spree/spree/commit/9e41f7da03a9fd87050a78033620225922574d14), [`9cd3d42`](https://github.com/spree/spree/commit/9cd3d42efa3aaf9297dd574a7d960f92a60b17e9), [`6742c1a`](https://github.com/spree/spree/commit/6742c1a868acc124b1773be8db187c7f512aa040), [`c2d6f40`](https://github.com/spree/spree/commit/c2d6f4091dadeefc20539e20cb91b788e490d03a), [`741345d`](https://github.com/spree/spree/commit/741345da3694a761b842f08ba4913abc9e23910a), [`a862b80`](https://github.com/spree/spree/commit/a862b80014fc5aa8ecddca1008917eda9f17635f), [`5f2b412`](https://github.com/spree/spree/commit/5f2b412966a3beb29ceab3e53064e00aec5ee93a), [`86d4b93`](https://github.com/spree/spree/commit/86d4b93193e9ee3537d61601a1b8f975f6cba679), [`854ebfe`](https://github.com/spree/spree/commit/854ebfe510cfded6d574485bb090e9a33e27e78d), [`61f902f`](https://github.com/spree/spree/commit/61f902f57228177e2944207f88508e235a030c9e), [`e601826`](https://github.com/spree/spree/commit/e601826eb3cc701bc918ae7ddb9c2c52598e02d7)]:
  - @spree/admin-sdk@1.0.0-beta.3
  - @spree/dashboard-core@1.0.0-beta.4
  - @spree/dashboard-ui@1.0.0-beta.4

## 1.0.0-beta.3

### Patch Changes

- [#14644](https://github.com/spree/spree/pull/14644) [`6723b99`](https://github.com/spree/spree/commit/6723b99bdf8453f6e3a2a6666211f69d658f566e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - First-run setup offers to load sample data. The load runs in the background once the admin account exists, so a fresh install gets demo products without a command line.

- [#14667](https://github.com/spree/spree/pull/14667) [`53008b4`](https://github.com/spree/spree/commit/53008b4a30eeca633206e726f0303f1f8c0673d3) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Re-export the framework and the design system, so an application has one import to remember.

  `@spree/dashboard` and `@spree/seller-dashboard` now expose everything from `@spree/dashboard-core` and `@spree/dashboard-ui`, and a host app writing its own pages no longer has to work out which package `useStore`, `Button` or `defineTable` lives in. Both packages stay importable directly, which is what a distributed plugin still does — it extends the shell rather than shipping it.

  A few names exist in both packages, where the design system ships a presentational component and the framework wraps it with data. `export *` drops such a name rather than picking one, so `ResourceCombobox`, `ResourceMultiAutocomplete`, `Slot`, `StatusCard` and `DateRange` resolved to the design system's version and the data-fetching one was unreachable through the shell. They are now re-exported explicitly, and a test fails when a new duplicate appears.

- Updated dependencies [[`20b5c2e`](https://github.com/spree/spree/commit/20b5c2e4fd50a83865d119e412caad1d2ad3bdad), [`6723b99`](https://github.com/spree/spree/commit/6723b99bdf8453f6e3a2a6666211f69d658f566e)]:
  - @spree/admin-sdk@1.0.0-beta.2
  - @spree/dashboard-core@1.0.0-beta.3
  - @spree/dashboard-ui@1.0.0-beta.3

## 1.0.0-beta.2

### Minor Changes

- Removed the address map from the design system.

  The map was rendered on one card — a seller's billing and returns addresses — and could not plot anything, because Spree addresses carry no coordinates. It also cost every dashboard user around a megabyte of MapLibre in the main bundle.

  Its `?worker&url` import made the package impossible to install, too: Vite's dependency optimizer cannot resolve that specifier inside `node_modules`, so any project depending on `@spree/dashboard-ui` failed to start its dev server. Projects on the previous release should upgrade.

### Patch Changes

- Updated dependencies []:
  - @spree/dashboard-ui@1.0.0-beta.2
  - @spree/dashboard-core@1.0.0-beta.2

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

- [#14633](https://github.com/spree/spree/pull/14633) [`c0f6ccd`](https://github.com/spree/spree/commit/c0f6ccd1c5e9df5d1dbb93d1aff9e4180d3979ea) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fix the dashboard date range picker remembering "Last 30 days" after another preset is chosen.

  The trigger label lived in local state that reset whenever analytics refetch replaced the page. It now follows the selected dates, so Last 90 days stays selected after the figures update.

- [#14413](https://github.com/spree/spree/pull/14413) [`99573b0`](https://github.com/spree/spree/commit/99573b0c717225e652e6d449b4b85f1e10f3600b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Edit the admin profile in a dialog opened from the user menu instead of a settings page. The `/settings/profile` route is removed; `TopBar` takes an `onEditProfile` handler and hides the menu item when none is supplied.

- [#14429](https://github.com/spree/spree/pull/14429) [`226557b`](https://github.com/spree/spree/commit/226557b21cc0870ee3803cdc617a2735311d9d9f) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Align status badge colours with the Geist colour system: each of the success, warning, destructive and info variants now pairs a tint with a matching reading colour from the same hue, in both light and dark themes, and every variant meets WCAG AA against its own fill. Fixes a `warning` badge that changed colour entirely on hover, and an outline badge whose border never rendered.

- [#14637](https://github.com/spree/spree/pull/14637) [`9b8a7d5`](https://github.com/spree/spree/commit/9b8a7d57967ec31659959547555dde6780e8ef10) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Keep list and quote toolbar buttons working after the TipTap 3.31 pin. Two copies of prosemirror-model made wrap throw; pinning one version (and deduping it in the Vite plugin) restores the stock TipTap commands. Enter still persists as its own paragraph.

- [#14532](https://github.com/spree/spree/pull/14532) [`be76364`](https://github.com/spree/spree/commit/be76364d999fcffeeedd8f980da1a581db62f4a1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Stop the admin sidebar's Cmd/Ctrl+B shortcut from firing while typing, and restore list, quote and link styling plus live toolbar states in the rich-text editor.

- [#14376](https://github.com/spree/spree/pull/14376) [`a52a6da`](https://github.com/spree/spree/commit/a52a6da42f5c456e889f8bba12ee7194934289b1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Dashboard features from the 6.0 core rewrite:

  - Delivery method editor: Conditions section (eligibility rules), pickup stock-location picker, calculator preferences through the shared preferences form.
  - Order page: discount code card (apply a typed code or pick a coupon promotion; pending codes show when they'll take effect) and a live computed-amount preview for percent manual discounts.
  - Webhook endpoint event catalog lists `order.placed`; delivery zones request members via `expand`.

- [#14461](https://github.com/spree/spree/pull/14461) [`32d4db9`](https://github.com/spree/spree/commit/32d4db9cdb027d9fb59e18807b26c0aa6ceb48ad) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Store credits no longer carry a category. `client.storeCreditCategories` and the `StoreCreditCategory` type are removed, `category_id` is no longer accepted or returned on customer store credits, and the dashboard's issue/edit store credit dialogs drop the category picker — the memo is the place to record why a credit was issued.

- [#14530](https://github.com/spree/spree/pull/14530) [`5d3520d`](https://github.com/spree/spree/commit/5d3520d800a1dbd6f07bb212eb41247ad375432c) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Show why an order tax line is zero.

  The Taxes card now names the treatment (buyer exempt, zero-rated, and the
  other recorded reasons) and, when the buyer is exempt, the certificate that
  made it so. A completed order with no matching rate says so instead of
  looking like a draft that has not been taxed yet, and the Summary card keeps
  its tax row at zero so an exempt sale is still visible there.

- [#14594](https://github.com/spree/spree/pull/14594) [`4156d50`](https://github.com/spree/spree/commit/4156d50a142497858377e3159a1c2c28182cb978) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Stop the translations editor marking itself dirty on open, and refresh the translations page after a save or a catalog edit.

  The rich-text cell was treating TipTap's mount-time paragraph wrap as an unsaved change against descriptions stored as plain text. Translation queries now share one cache prefix so saving a translation, editing the source record, or importing a translations CSV invalidates the coverage grid instead of leaving it stale.

- Updated dependencies [[`9cee487`](https://github.com/spree/spree/commit/9cee487fdce34c5f2ec873fc1d965196bd716663), [`4df88ac`](https://github.com/spree/spree/commit/4df88ac684688e65623703544686c6043a8ed816), [`6d4fe64`](https://github.com/spree/spree/commit/6d4fe64a1444bc42338942025a4ed1d5788cb9d7), [`67594a5`](https://github.com/spree/spree/commit/67594a56921fbc5d584b371ede94b0b83f2035ea), [`a8b11ec`](https://github.com/spree/spree/commit/a8b11ecb409a04c8d48ec6d64892ffa3bd6dacf7), [`fdd88eb`](https://github.com/spree/spree/commit/fdd88eb3d2d7ac36a710a2af38593a8f4c83f2bf), [`c0f6ccd`](https://github.com/spree/spree/commit/c0f6ccd1c5e9df5d1dbb93d1aff9e4180d3979ea), [`99573b0`](https://github.com/spree/spree/commit/99573b0c717225e652e6d449b4b85f1e10f3600b), [`3a1ac28`](https://github.com/spree/spree/commit/3a1ac2851a59cf0e498af27a60e70caac3a5788e), [`027ed08`](https://github.com/spree/spree/commit/027ed08056df9608554c80e343cdf24d6699d9f5), [`226557b`](https://github.com/spree/spree/commit/226557b21cc0870ee3803cdc617a2735311d9d9f), [`eb59f05`](https://github.com/spree/spree/commit/eb59f05f18dc98b62413ca80cc0061dfafd08ef7), [`9a4eb46`](https://github.com/spree/spree/commit/9a4eb466c2698d15d735c06e4b5faf984bb63dd2), [`38207ce`](https://github.com/spree/spree/commit/38207ceca55aaa1ac7606a2aca3098c441c77758), [`889a8cf`](https://github.com/spree/spree/commit/889a8cfd24443710cfff5a7d30fbe83d65148cac), [`8e5dc20`](https://github.com/spree/spree/commit/8e5dc20147ff24f53dd73b506c3f06a074d3d302), [`676aa0d`](https://github.com/spree/spree/commit/676aa0dee62a26944cb0a2c83273b149ba922b8a), [`9b8a7d5`](https://github.com/spree/spree/commit/9b8a7d57967ec31659959547555dde6780e8ef10), [`be76364`](https://github.com/spree/spree/commit/be76364d999fcffeeedd8f980da1a581db62f4a1), [`7e35951`](https://github.com/spree/spree/commit/7e35951361a6cee7b735640b0228710928719fee), [`496431d`](https://github.com/spree/spree/commit/496431d8e902269b8a5b05c9f2393eafc7e6b78b), [`a52a6da`](https://github.com/spree/spree/commit/a52a6da42f5c456e889f8bba12ee7194934289b1), [`0f22450`](https://github.com/spree/spree/commit/0f224508b3d270aaa9899a508966a27c37f873ed), [`da49f27`](https://github.com/spree/spree/commit/da49f27a5da1e40dbd4ce0901f8d4b21573d98df), [`32d4db9`](https://github.com/spree/spree/commit/32d4db9cdb027d9fb59e18807b26c0aa6ceb48ad), [`abc6e22`](https://github.com/spree/spree/commit/abc6e22cb60ea305a83583ded0b999458b2c9cbd), [`3473696`](https://github.com/spree/spree/commit/3473696bb08408addca8ef4665748c694b64b6d1), [`4156d50`](https://github.com/spree/spree/commit/4156d50a142497858377e3159a1c2c28182cb978)]:
  - @spree/dashboard-core@1.0.0-beta.1
  - @spree/admin-sdk@1.0.0-beta.1
  - @spree/dashboard-ui@1.0.0-beta.1

## 0.13.1

### Patch Changes

- [#14363](https://github.com/spree/spree/pull/14363) [`705e515`](https://github.com/spree/spree/commit/705e515ac881d071f45c768359380bd0ea5d23bd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The import and export buttons now pass the API type shorthand (`"products"`, `"customers"`, `"orders"`, `"coupon_codes"`) instead of the Ruby class name, and the import wizard reads the shorthand the API returns. Values in the older `Spree::Imports::Products` form are still understood, so an import opened from a cached payload keeps rendering its type and "view records" link correctly.

- [#14353](https://github.com/spree/spree/pull/14353) [`8bf0dd0`](https://github.com/spree/spree/commit/8bf0dd070c9369549c54a9233bca97111d7aff11) Thanks [@ifizza](https://github.com/ifizza)! - Searchable and sortable custom fields now appear as first-class product table columns. Definitions can be marked searchable/sortable from the definition form, and the new `metafieldColumns` prop on `ResourceTable` merges them into the column selector, the Sort dropdown, and the filter panel — with operators matching each field type. `ColumnDef` gains an `expand` field so a visible column can declare the association the list request must expand.

- Updated dependencies [[`8bf0dd0`](https://github.com/spree/spree/commit/8bf0dd070c9369549c54a9233bca97111d7aff11), [`f811d1e`](https://github.com/spree/spree/commit/f811d1ee5f604e24f86aa59be3317f87627fe3c7), [`8bf0dd0`](https://github.com/spree/spree/commit/8bf0dd070c9369549c54a9233bca97111d7aff11), [`705e515`](https://github.com/spree/spree/commit/705e515ac881d071f45c768359380bd0ea5d23bd), [`705e515`](https://github.com/spree/spree/commit/705e515ac881d071f45c768359380bd0ea5d23bd), [`f811d1e`](https://github.com/spree/spree/commit/f811d1ee5f604e24f86aa59be3317f87627fe3c7)]:
  - @spree/admin-sdk@0.8.1
  - @spree/dashboard-core@0.13.1
  - @spree/dashboard-ui@0.13.1

## 0.13.0

### Minor Changes

- [#14342](https://github.com/spree/spree/pull/14342) [`202d846`](https://github.com/spree/spree/commit/202d846374270c75e19b23cea5498ea559577f67) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Add per-channel order routing rule management. `@spree/admin-sdk` gains `channels.orderRoutingRules.{list,get,create,update,delete}` (nested under `/channels/:channel_id/order_routing_rules`) plus `orderRoutingRules.types()` for rule-kind discovery; the admin `Store` type now exposes `preferred_order_routing_strategy`. The dashboard's channel edit sheet embeds a routing-rules editor — drag-to-reorder priority, per-rule active toggles, an "Add rule" picker fed by the types endpoint (offering only kinds not yet on the channel; rule kinds are unique per channel), and schema-driven preference forms for rule kinds that declare preferences. The editor renders only when the channel's effective routing strategy is Rules. `Subject.OrderRoutingRule` is available for permission checks.

- [#14341](https://github.com/spree/spree/pull/14341) [`dc33237`](https://github.com/spree/spree/commit/dc332372b918ffeb92252c33372a1d71a221a7d4) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Improve editing of quantity-bounded price rules. A blank upper-bound preference (`max_quantity`, `max_uses`, `maximum_amount`, …) now shows "Unlimited" instead of an empty required-looking field across every preferences form. The Volume price rule gains a dedicated editor that renders minimum quantity before maximum, so a case-pack minimum reads in a natural order.

### Patch Changes

- Updated dependencies [[`202d846`](https://github.com/spree/spree/commit/202d846374270c75e19b23cea5498ea559577f67), [`dc33237`](https://github.com/spree/spree/commit/dc332372b918ffeb92252c33372a1d71a221a7d4)]:
  - @spree/admin-sdk@0.8.0
  - @spree/dashboard-core@0.13.0
  - @spree/dashboard-ui@0.13.0

## 0.12.0

### Minor Changes

- [#14339](https://github.com/spree/spree/pull/14339) [`b71e613`](https://github.com/spree/spree/commit/b71e61326289d7ef4038a4bd55f353569a242d52) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Re-export the plugin facade (`defineDashboardPlugin` and its types) from `@spree/dashboard`, so host apps can register in-app customizations without declaring `@spree/dashboard-core` as a direct dependency. Distributed plugins keep importing from `@spree/dashboard-core/plugin`.

### Patch Changes

- Updated dependencies []:
  - @spree/dashboard-core@0.12.0
  - @spree/dashboard-ui@0.12.0

## 0.11.0

### Minor Changes

- Manage channel binding for publishable API keys. The create dialog offers an optional channel select (defaulting to all channels) when the key type is publishable, and the publishable keys table gains a Channel column showing each key's bound channel or "All channels".

## 0.10.3

### Patch Changes

- Refresh resource lists when a CSV import finishes. Imports create records server-side outside any tracked mutation, and the list under the import wizard stays mounted — so it kept serving the pre-import cache. The import's target resources (plus option types and categories for product imports) and the imports history are now invalidated whenever the poll observes the run finishing, including failed and retried runs.

## 0.10.2

### Patch Changes

- Fix the product edit form collapsing multi-paragraph descriptions on reload. The description editor now hydrates from the API's `description_html` field instead of the tag-stripped plain-text `description`, so paragraphs, line breaks, and inline formatting survive save and reload cycles.
