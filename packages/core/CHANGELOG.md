# @spree/core

## 6.0.1

### Patch Changes

- [#15001](https://github.com/spree/spree/pull/15001) [`21dc28f`](https://github.com/spree/spree/commit/21dc28f68623bcd141a349b597b8b872fd57b9dd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Typed the store's regional settings. The store's `default_country_code` is now `CountryCode`, its `admin_locale` is `LocaleCode` (send `null` to clear it), and its `timezone` — also on the seller profile — is the new `TimeZone` type, which suggests common IANA time zones while accepting any other. `TIME_ZONES` in `@spree/core` lists the suggested zones.

## 6.0.0

### Minor Changes

- [#14982](https://github.com/spree/spree/pull/14982) [`348c5bb`](https://github.com/spree/spree/commit/348c5bbeb94eb73dacbe3dbe10b8951eb469c553) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `MaintenanceTaskRunStatus` and `MAINTENANCE_TASK_RUN_STATUSES`, the statuses a maintenance task run moves through.

## 6.0.0-rc.7

Released with Spree 6.0.0.rc7, with no changes of its own. From this release the version matches the version of the Spree gems.

## 0.3.0

### Minor Changes

- [#14970](https://github.com/spree/spree/pull/14970) [`fb8a9ce`](https://github.com/spree/spree/commit/fb8a9ce01e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - A webhook endpoint's subscriptions must now be `*`, an event name, or a name with `*` in place of whole segments (`order.*`, `*.created`), with at most 200 entries of up to 100 characters each; the API's 422 names the rejected entries. `@spree/core` exports the rule as `WEBHOOK_EVENT_PATTERN`, `isWebhookEventPattern`, `WEBHOOK_SUBSCRIPTION_MAX_LENGTH` and `WEBHOOK_SUBSCRIPTIONS_MAX`, and the dashboard's webhook form checks it before saving, refusing an invalid custom event inline. `FieldError` no longer crashes on the sparse per-item error array react-hook-form produces.

## 0.2.0

### Minor Changes

- [#14944](https://github.com/spree/spree/pull/14944) [`a0e5b66`](https://github.com/spree/spree/commit/a0e5b66419569d1e91d3b1eaf180444b73c65cd1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added every status, kind and other value list the Spree API returns to `@spree/core`, each as a list of its values (`PRODUCT_STATUSES`, `MEDIA_TYPES`, …) and a type (`ProductStatus`, `MediaType`, …) — open where extensions may add values, closed otherwise — plus `subsetOf` for picking the values an action accepts with each one checked at compile time. The SDKs re-export these types instead of each carrying its own copy, so their names and values are unchanged. The dashboards and the seller panel build their status filters and action checks from these lists, so a status added on the server shows up without a dashboard change. Value lists the SDKs used to spell out inline, such as a seller transfer's `kind`, now have names of their own; `MediaType`, `CollectionRuleMatchPolicy` and `CollectionSortOrder` in `@spree/admin-sdk`, and `ClaimResolution` in `@spree/dashboard-ui`, now come from the generated lists under the same names. A seller's `tax_remittance` and `payouts_schedule_interval`, a claim's `resolution`, a collection's `sort_order`, a shipping label's `format`, purchase order and stock transfer statuses, and tax and commission lines' `taxability_reason` are now typed with their lists instead of as plain strings.
