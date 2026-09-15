# @spree/dashboard-ui

## 1.0.0-beta.2

### Minor Changes

- Removed the address map from the design system.

  The map was rendered on one card — a seller's billing and returns addresses — and could not plot anything, because Spree addresses carry no coordinates. It also cost every dashboard user around a megabyte of MapLibre in the main bundle.

  Its `?worker&url` import made the package impossible to install, too: Vite's dependency optimizer cannot resolve that specifier inside `node_modules`, so any project depending on `@spree/dashboard-ui` failed to start its dev server. Projects on the previous release should upgrade.

## 1.0.0-beta.1

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

- [#14633](https://github.com/spree/spree/pull/14633) [`c0f6ccd`](https://github.com/spree/spree/commit/c0f6ccd1c5e9df5d1dbb93d1aff9e4180d3979ea) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fix the dashboard date range picker remembering "Last 30 days" after another preset is chosen.

  The trigger label lived in local state that reset whenever analytics refetch replaced the page. It now follows the selected dates, so Last 90 days stays selected after the figures update.

- [#14378](https://github.com/spree/spree/pull/14378) [`027ed08`](https://github.com/spree/spree/commit/027ed08056df9608554c80e343cdf24d6699d9f5) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Redesign the user dropdown's theme and language controls into a compact "Preferences" section: theme is now a segmented control (System / Light / Dark) and language is a select-style pill.

- [#14429](https://github.com/spree/spree/pull/14429) [`226557b`](https://github.com/spree/spree/commit/226557b21cc0870ee3803cdc617a2735311d9d9f) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Align status badge colours with the Geist colour system: each of the success, warning, destructive and info variants now pairs a tint with a matching reading colour from the same hue, in both light and dark themes, and every variant meets WCAG AA against its own fill. Fixes a `warning` badge that changed colour entirely on hover, and an outline badge whose border never rendered.

- [#14502](https://github.com/spree/spree/pull/14502) [`eb59f05`](https://github.com/spree/spree/commit/eb59f05f18dc98b62413ca80cc0061dfafd08ef7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Declare the dependencies behind `styles.css` imports: `tailwindcss` as a peer (plus dev) dependency and `shadcn` as a regular dependency. Previously both were undeclared for consumers, so `@import "tailwindcss"` and `@import "shadcn/tailwind.css"` only resolved when pnpm's on-disk layout happened to allow it, failing with `Cannot apply unknown utility class` otherwise.

- [#14631](https://github.com/spree/spree/pull/14631) [`38207ce`](https://github.com/spree/spree/commit/38207ceca55aaa1ac7606a2aca3098c441c77758) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Hide the pagination footer when a list has no rows, so empty tables no longer show "0–0 of 0" or a rows-per-page control.

- [#14637](https://github.com/spree/spree/pull/14637) [`9b8a7d5`](https://github.com/spree/spree/commit/9b8a7d57967ec31659959547555dde6780e8ef10) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Keep list and quote toolbar buttons working after the TipTap 3.31 pin. Two copies of prosemirror-model made wrap throw; pinning one version (and deduping it in the Vite plugin) restores the stock TipTap commands. Enter still persists as its own paragraph.

- [#14532](https://github.com/spree/spree/pull/14532) [`be76364`](https://github.com/spree/spree/commit/be76364d999fcffeeedd8f980da1a581db62f4a1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Stop the admin sidebar's Cmd/Ctrl+B shortcut from firing while typing, and restore list, quote and link styling plus live toolbar states in the rich-text editor.

- [#14594](https://github.com/spree/spree/pull/14594) [`4156d50`](https://github.com/spree/spree/commit/4156d50a142497858377e3159a1c2c28182cb978) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Stop the translations editor marking itself dirty on open, and refresh the translations page after a save or a catalog edit.

  The rich-text cell was treating TipTap's mount-time paragraph wrap as an unsaved change against descriptions stored as plain text. Translation queries now share one cache prefix so saving a translation, editing the source record, or importing a translations CSV invalidates the coverage grid instead of leaving it stale.

## 0.13.1

## 0.13.0

### Minor Changes

- [#14342](https://github.com/spree/spree/pull/14342) [`202d846`](https://github.com/spree/spree/commit/202d846374270c75e19b23cea5498ea559577f67) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Add per-channel order routing rule management. `@spree/admin-sdk` gains `channels.orderRoutingRules.{list,get,create,update,delete}` (nested under `/channels/:channel_id/order_routing_rules`) plus `orderRoutingRules.types()` for rule-kind discovery; the admin `Store` type now exposes `preferred_order_routing_strategy`. The dashboard's channel edit sheet embeds a routing-rules editor — drag-to-reorder priority, per-rule active toggles, an "Add rule" picker fed by the types endpoint (offering only kinds not yet on the channel; rule kinds are unique per channel), and schema-driven preference forms for rule kinds that declare preferences. The editor renders only when the channel's effective routing strategy is Rules. `Subject.OrderRoutingRule` is available for permission checks.

## 0.12.0
