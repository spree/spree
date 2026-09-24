# @spree/seller-dashboard

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
