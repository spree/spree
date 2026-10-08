# @spree/seller-dashboard

## 1.0.0-rc.1

### Minor Changes

- [#14784](https://github.com/spree/spree/pull/14784) [`a4baf49`](https://github.com/spree/spree/commit/a4baf4900f24739125d8efceaba5fb7e70a7fea9) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Plugins can now add cards to more detail pages. The admin dashboard has new slots on the seller payout, catalog, price list, promotion, purchase order, stock transfer and webhook endpoint pages, and the catalog, price list and promotion pages now save extension fields bound with `useHostForm()` with the page's own Save button. The seller panel has new slots on its product, order, payout and profile pages, and its product page saves extension fields the same way, under the form key `seller.product`. The slots catalog lists every slot and the context it receives.

### Patch Changes

- [#14776](https://github.com/spree/spree/pull/14776) [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57) Thanks [@mad-eel](https://github.com/mad-eel)! - The New claim dialog now pre-fills each line's refund with what the customer paid for those items after discounts, instead of their list price, which the claim would refuse to refund on a discounted order. The amount follows the claimed quantity until the merchant types one of their own. Code that builds the dialog's lines itself passes `discountedAmount` (the line's `discounted_amount`) in place of `price`, which `ClaimableLine` no longer accepts.

- [#14776](https://github.com/spree/spree/pull/14776) [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57) Thanks [@mad-eel](https://github.com/mad-eel)! - A received return that is owed nothing, such as a free gift sent back, now offers "Complete return" instead of "Refund". The dialog explains that no money goes back and closes the return without asking for an amount or a refund method.

- [#14799](https://github.com/spree/spree/pull/14799) [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da) Thanks [@mad-eel](https://github.com/mad-eel)! - The refund dialog says how much tax the pre-filled amount gives back, and the claim dialog pre-fills each line with the tax the customer paid on top of the price. Shipping an exchange whose replacement costs more asks first, because the difference is added to the order as a balance due, and that fee is labelled "Exchange" on the order.

- [#14799](https://github.com/spree/spree/pull/14799) [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da) Thanks [@mad-eel](https://github.com/mad-eel)! - Admin returns carry `display_refunded_total`. A refunded return's card in the dashboard and the seller panel now shows what was actually refunded instead of what the return was worth, and names both when less went back, for example "Refunded $25.00 of $30.26".

- [#14764](https://github.com/spree/spree/pull/14764) [`291238d`](https://github.com/spree/spree/commit/291238dfc0b05f9b322f9e51d6cd3737006ba430) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fixed the seller panel opening with an empty sidebar when a seller returned with a live session but no remembered seller, for example after the browser cleared site storage. The panel now loads the seller's permissions once it knows which seller is active.

- [#14747](https://github.com/spree/spree/pull/14747) [`a0151c1`](https://github.com/spree/spree/commit/a0151c15a268356f5a5ba236850b8ee7405e9ae7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fixed the setup screen of a new project reloading while the merchant was filling it in. The generated route file now refers to installed packages by their stable location, and `spree add` generates it right after installing, so the first dev start has nothing to rewrite. Upgrades also no longer rewrite every line of that file, so its diff shows only the pages an upgrade added.

- Updated dependencies [[`3b80c52`](https://github.com/spree/spree/commit/3b80c52d19006dafc717e4004ec9ae4619438b7b), [`f52fc12`](https://github.com/spree/spree/commit/f52fc12c788bae7edcba264e43e5da7a6c58f25f), [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57), [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57), [`4bd1741`](https://github.com/spree/spree/commit/4bd1741677b202f11c13b792bf16e62301d2c5cd), [`7fa7a64`](https://github.com/spree/spree/commit/7fa7a647d5372641fa45ff6fc9c52892bf791a1c), [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da), [`3a2a78b`](https://github.com/spree/spree/commit/3a2a78bb43f84a2da1570ebb29c197e6ae1f1c98), [`446d3cb`](https://github.com/spree/spree/commit/446d3cbc71b3ff980d48559317089e13eaab564e), [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da), [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da), [`291238d`](https://github.com/spree/spree/commit/291238dfc0b05f9b322f9e51d6cd3737006ba430), [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57), [`95c27af`](https://github.com/spree/spree/commit/95c27af49ace4316699f863a023671b236e2f467), [`a0151c1`](https://github.com/spree/spree/commit/a0151c15a268356f5a5ba236850b8ee7405e9ae7), [`f52fc12`](https://github.com/spree/spree/commit/f52fc12c788bae7edcba264e43e5da7a6c58f25f), [`f52fc12`](https://github.com/spree/spree/commit/f52fc12c788bae7edcba264e43e5da7a6c58f25f), [`53d9925`](https://github.com/spree/spree/commit/53d9925440d62343d77efad3c8dc849c4fa54008)]:
  - @spree/seller-sdk@1.0.0
  - @spree/dashboard-ui@1.0.0
  - @spree/dashboard-core@1.0.0

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

### Patch Changes

- [#14736](https://github.com/spree/spree/pull/14736) [`e601826`](https://github.com/spree/spree/commit/e601826eb3cc701bc918ae7ddb9c2c52598e02d7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Invitation listings no longer include `acceptance_url`, because the link carries the token that accepts the invitation. Fetch it on demand with `invitations.acceptanceLink(id)` (and `sellers.invitations.acceptanceLink(sellerId, id)` in the Admin SDK), which needs write access. The "Copy invitation link" actions in the dashboard and the seller panel now use it.

- Updated dependencies [[`9cd3d42`](https://github.com/spree/spree/commit/9cd3d42efa3aaf9297dd574a7d960f92a60b17e9), [`6742c1a`](https://github.com/spree/spree/commit/6742c1a868acc124b1773be8db187c7f512aa040), [`c2d6f40`](https://github.com/spree/spree/commit/c2d6f4091dadeefc20539e20cb91b788e490d03a), [`741345d`](https://github.com/spree/spree/commit/741345da3694a761b842f08ba4913abc9e23910a), [`a862b80`](https://github.com/spree/spree/commit/a862b80014fc5aa8ecddca1008917eda9f17635f), [`5f2b412`](https://github.com/spree/spree/commit/5f2b412966a3beb29ceab3e53064e00aec5ee93a), [`86d4b93`](https://github.com/spree/spree/commit/86d4b93193e9ee3537d61601a1b8f975f6cba679), [`854ebfe`](https://github.com/spree/spree/commit/854ebfe510cfded6d574485bb090e9a33e27e78d), [`61f902f`](https://github.com/spree/spree/commit/61f902f57228177e2944207f88508e235a030c9e), [`e601826`](https://github.com/spree/spree/commit/e601826eb3cc701bc918ae7ddb9c2c52598e02d7)]:
  - @spree/dashboard-core@1.0.0-beta.4
  - @spree/dashboard-ui@1.0.0-beta.4
  - @spree/seller-sdk@1.0.0-beta.3

## 1.0.0-beta.3

### Patch Changes

- [#14667](https://github.com/spree/spree/pull/14667) [`53008b4`](https://github.com/spree/spree/commit/53008b4a30eeca633206e726f0303f1f8c0673d3) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Re-export the framework and the design system, so an application has one import to remember.

  `@spree/dashboard` and `@spree/seller-dashboard` now expose everything from `@spree/dashboard-core` and `@spree/dashboard-ui`, and a host app writing its own pages no longer has to work out which package `useStore`, `Button` or `defineTable` lives in. Both packages stay importable directly, which is what a distributed plugin still does — it extends the shell rather than shipping it.

  A few names exist in both packages, where the design system ships a presentational component and the framework wraps it with data. `export *` drops such a name rather than picking one, so `ResourceCombobox`, `ResourceMultiAutocomplete`, `Slot`, `StatusCard` and `DateRange` resolved to the design system's version and the data-fetching one was unreachable through the shell. They are now re-exported explicitly, and a test fails when a new duplicate appears.

- Updated dependencies []:
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

### Patch Changes

- [#14635](https://github.com/spree/spree/pull/14635) [`496431d`](https://github.com/spree/spree/commit/496431d8e902269b8a5b05c9f2393eafc7e6b78b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added a settings overview page to the seller panel, matching the operator dashboard's card grid of reachable settings areas.

- Updated dependencies [[`9cee487`](https://github.com/spree/spree/commit/9cee487fdce34c5f2ec873fc1d965196bd716663), [`67594a5`](https://github.com/spree/spree/commit/67594a56921fbc5d584b371ede94b0b83f2035ea), [`fdd88eb`](https://github.com/spree/spree/commit/fdd88eb3d2d7ac36a710a2af38593a8f4c83f2bf), [`c0f6ccd`](https://github.com/spree/spree/commit/c0f6ccd1c5e9df5d1dbb93d1aff9e4180d3979ea), [`99573b0`](https://github.com/spree/spree/commit/99573b0c717225e652e6d449b4b85f1e10f3600b), [`3a1ac28`](https://github.com/spree/spree/commit/3a1ac2851a59cf0e498af27a60e70caac3a5788e), [`027ed08`](https://github.com/spree/spree/commit/027ed08056df9608554c80e343cdf24d6699d9f5), [`226557b`](https://github.com/spree/spree/commit/226557b21cc0870ee3803cdc617a2735311d9d9f), [`eb59f05`](https://github.com/spree/spree/commit/eb59f05f18dc98b62413ca80cc0061dfafd08ef7), [`38207ce`](https://github.com/spree/spree/commit/38207ceca55aaa1ac7606a2aca3098c441c77758), [`8e5dc20`](https://github.com/spree/spree/commit/8e5dc20147ff24f53dd73b506c3f06a074d3d302), [`9b8a7d5`](https://github.com/spree/spree/commit/9b8a7d57967ec31659959547555dde6780e8ef10), [`be76364`](https://github.com/spree/spree/commit/be76364d999fcffeeedd8f980da1a581db62f4a1), [`496431d`](https://github.com/spree/spree/commit/496431d8e902269b8a5b05c9f2393eafc7e6b78b), [`0f22450`](https://github.com/spree/spree/commit/0f224508b3d270aaa9899a508966a27c37f873ed), [`da49f27`](https://github.com/spree/spree/commit/da49f27a5da1e40dbd4ce0901f8d4b21573d98df), [`3473696`](https://github.com/spree/spree/commit/3473696bb08408addca8ef4665748c694b64b6d1), [`4156d50`](https://github.com/spree/spree/commit/4156d50a142497858377e3159a1c2c28182cb978)]:
  - @spree/dashboard-core@1.0.0-beta.1
  - @spree/dashboard-ui@1.0.0-beta.1
  - @spree/seller-sdk@1.0.0-beta.1
