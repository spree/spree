# @spree/seller-sdk

## 1.0.0-rc.1

### Minor Changes

- [#14837](https://github.com/spree/spree/pull/14837) [`3b80c52`](https://github.com/spree/spree/commit/3b80c52d19006dafc717e4004ec9ae4619438b7b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed every type value the APIs send or accept to a short name instead of a Ruby class name: delivery method, digital asset, payout, tax and pickup point providers (`manual`, `internal`, `system`, `file`), order routing strategies (`rules`), custom field definition `resource_type` (`product`, `category`), tag `taggable_type`, the owner and originator types on addresses, refunds and media usage, payment setup session `payment_source_type` (`credit_card`), and type filters such as `type_eq` and `receivable_type_eq`. Removed `integration_class` from the provider listings and the deprecated custom field `type` field (use `field_type`), and corrected the shipping label `owner_type` type to `'fulfillment' | 'return'`.

- [#14799](https://github.com/spree/spree/pull/14799) [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da) Thanks [@mad-eel](https://github.com/mad-eel)! - Returns, claims and exchanges now give back the tax the customer paid. Return lines carry `included_tax_total`, `additional_tax_total`, `tax_total` and `refund_amount` (tax included), and returns carry `refund_tax_total`. On a store whose prices include VAT, a return line's `pre_tax_amount` now reads the price before tax rather than the gross price. Claim and exchange lines carry the tax on each half, tax lines name the return, claim or exchange line they belong to and whether they are a `credit`, Admin refunds carry `tax_amount`, and Seller order line items carry `additional_tax_total`. Fees gain the `exchange` kind.

- [#14776](https://github.com/spree/spree/pull/14776) [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57) Thanks [@mad-eel](https://github.com/mad-eel)! - Order line items now carry `discounted_amount` and `display_discounted_amount`: what the customer paid for the line after discounts, which is also the most a claim on it can refund.

- [#14780](https://github.com/spree/spree/pull/14780) [`95c27af`](https://github.com/spree/spree/commit/95c27af49ace4316699f863a023671b236e2f467) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `client.me` is now an object: read the signed-in person with `client.me.get()` and edit their own account — first and last name, photo (`avatar`: a direct-upload signed id, or `null` to remove it) and the panel's `selected_locale` — with `client.me.update(params)`. `me.get()` and `me.update()` return `user` as an `Account`, which adds `selected_locale` to the fields `TeamMember` had.

  1.0.0-beta.3 made this change without keeping the old form, so code written against beta.1 or beta.2 failed with `client.me is not a function`. Calling `client.me()` works again and returns the same response as `client.me.get()`, but it is deprecated and logs a one-time `console.warn`. To migrate, replace `client.me()` with `client.me.get()`.

- [#14763](https://github.com/spree/spree/pull/14763) [`53d9925`](https://github.com/spree/spree/commit/53d9925440d62343d77efad3c8dc849c4fa54008) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added runtime Zod schemas to the Admin and Seller SDKs, exported from `@spree/admin-sdk/zod` and `@spree/seller-sdk/zod`, matching what `@spree/sdk/zod` already offers for the Store API. Schemas for inline objects, unions and records are now precise instead of accepting any value, which also tightens a few Store SDK schemas (cart warnings, payment sources, product filters).

### Patch Changes

- [#14839](https://github.com/spree/spree/pull/14839) [`446d3cb`](https://github.com/spree/spree/commit/446d3cbc71b3ff980d48559317089e13eaab564e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed permission subjects to short names: `/me` returns `product`, `category`, `customer` instead of Ruby class names, and the `Subject` constants, `<Can>` checks and navigation `subject` entries use the same names. Plugins that pass class names (`'Spree::Order'`) to `permissions.can`, `<Can>` or a navigation entry must switch to the short name (`'order'`) or a `Subject` constant. Category checks now work for roles without full access.

## 1.0.0-beta.3

### Minor Changes

- [#14736](https://github.com/spree/spree/pull/14736) [`e601826`](https://github.com/spree/spree/commit/e601826eb3cc701bc918ae7ddb9c2c52598e02d7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Invitation listings no longer include `acceptance_url`, because the link carries the token that accepts the invitation. Fetch it on demand with `invitations.acceptanceLink(id)` (and `sellers.invitations.acceptanceLink(sellerId, id)` in the Admin SDK), which needs write access. The "Copy invitation link" actions in the dashboard and the seller panel now use it.

## 1.0.0-beta.2

### Patch Changes

- Released alongside the dashboard packages it is versioned with.

## 1.0.0-beta.1

### Patch Changes

- [#14593](https://github.com/spree/spree/pull/14593) [`0f22450`](https://github.com/spree/spree/commit/0f224508b3d270aaa9899a508966a27c37f873ed) Thanks [@Hemang-ai](https://github.com/Hemang-ai)! - Preserve HTTP error statuses when a server returns an empty, non-JSON, or malformed error body. Avoid treating these responses as network failures, and allow admin and seller session recovery to handle unauthorized responses.
