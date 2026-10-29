# @spree/seller-sdk

## 6.0.0

No changes in this release.

## 6.0.0-rc.7

Released with Spree 6.0.0.rc7, with no changes of its own. From this release the version matches the version of the Spree gems.

## 1.0.0-rc.6

### Minor Changes

- [#14971](https://github.com/spree/spree/pull/14971) [`98a79ca`](https://github.com/spree/spree/commit/98a79cab9387f5c0cd3ee55770305fcc8285111d) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Sellers can manage the downloadable files on their own digital products. The Seller SDK adds `products.digitalAssets` (`list`, `get`, `create`, `update`, `delete`), and the seller panel's product page shows the same Digital files card as the dashboard: upload, replace and delete files, and set per-file download limits. A file the marketplace delivers through its own provider is listed but cannot be replaced by the seller. The card now lives in `@spree/dashboard-core` as `DigitalAssetsCard`, and a panel enables it by registering `digitalAssets` on its API client; `readOnly` shows the files without any way to change them and `accept` narrows the file picker.
  
  Seller uploads are a marketplace decision: three store settings, edited on the dashboard's Marketplace settings page, say whether sellers may upload at all (off by default), which content types their files may have, and whether a file added to or replaced on an approved product sends it back to review. The seller `/me` response carries them under `store`, and the Admin SDK's `Store` type gains the three fields.

## 1.0.0-rc.5

### Patch Changes

- [#14933](https://github.com/spree/spree/pull/14933) [`1a86817`](https://github.com/spree/spree/commit/1a86817598711e5383d9acd663bbe808448a9dd2) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Order filter and sort types include `market_id` and `locale`. Locale, currency and country filters (`locale`, `currency`, `cost_currency`, `country_code`, `country_of_origin`) accept only `LocaleCode`, `CurrencyCode` and `CountryCode` values (new `CodeFilters` type) instead of free text.

- [#14944](https://github.com/spree/spree/pull/14944) [`a0e5b66`](https://github.com/spree/spree/commit/a0e5b66419569d1e91d3b1eaf180444b73c65cd1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added every status, kind and other value list the Spree API returns to `@spree/core`, each as a list of its values (`PRODUCT_STATUSES`, `MEDIA_TYPES`, …) and a type (`ProductStatus`, `MediaType`, …) — open where extensions may add values, closed otherwise — plus `subsetOf` for picking the values an action accepts with each one checked at compile time. The SDKs re-export these types instead of each carrying its own copy, so their names and values are unchanged. The dashboards and the seller panel build their status filters and action checks from these lists, so a status added on the server shows up without a dashboard change. Value lists the SDKs used to spell out inline, such as a seller transfer's `kind`, now have names of their own; `MediaType`, `CollectionRuleMatchPolicy` and `CollectionSortOrder` in `@spree/admin-sdk`, and `ClaimResolution` in `@spree/dashboard-ui`, now come from the generated lists under the same names. A seller's `tax_remittance` and `payouts_schedule_interval`, a claim's `resolution`, a collection's `sort_order`, a shipping label's `format`, purchase order and stock transfer statuses, and tax and commission lines' `taxability_reason` are now typed with their lists instead of as plain strings.

- [#14936](https://github.com/spree/spree/pull/14936) [`06fc8b0`](https://github.com/spree/spree/commit/06fc8b06574742b63f15e355ea352f67655459c1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Weight and dimension units are closed code lists, exported as `WeightUnit` and `DimensionUnit` (values and types) like `CountryCode` and `CurrencyCode`, and every unit field in responses and request types uses them; unit fields in requests accept `null` to fall back to the store default. The Admin and Seller SDKs publish one `VariantParams` type: `ProductVariantParams`, `VariantCreateParams` and `VariantUpdateParams` build on it. The Seller SDK's `SellerProductVariantParams` is renamed to `ProductVariantParams` (the old name stays as a deprecated alias). The variant editor and bulk variant editor now offer feet as a dimension unit.

## 1.0.0-rc.4

### Minor Changes

- [#14900](https://github.com/spree/spree/pull/14900) [`11b9a03`](https://github.com/spree/spree/commit/11b9a03c775fce616a9cd73cb39fa47e7b88bb13) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `CountryCode`, `CurrencyCode` and `LocaleCode` as values as well as types, so you can write `CurrencyCode.USD`, list every code with `Object.values(CurrencyCode)` and see each code's name in your editor. Plain strings such as `'USD'` still type-check.

## 1.0.0-rc.3

### Patch Changes

- Entries of `q` on every list method always stay inside `q`, even one named `page` or `sort`, and nested objects are sent in bracket form.

  `sumMoney`, `subtractMoney`, `multiplyMoney` and `negateMoney` now write every result the same way: with the decimals their inputs carry, and at least the currency's when one is given (`sumMoney(['1.50', '2.50'])` is `"4.00"`, not `"4"`). Nothing is rounded away. `formatMoney` returns an empty string for a currency `Intl` does not know, falls back to the reader's language for a locale it does not know, and no longer shows a minus sign on an amount that rounds to zero.

## 1.0.0-rc.2

### Minor Changes

- [#14856](https://github.com/spree/spree/pull/14856) [`05d6372`](https://github.com/spree/spree/commit/05d637294259a03b53e1849be6638bcb2b328d14) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The Admin and Seller APIs no longer return `display_*` money fields, so their types drop them; format the amount with its currency instead. The dashboard and seller panel format every amount in the admin's own language. `formatMoney` writes a currency's ISO 4217 decimals and takes `{ unitPrice: true }` for up to four.

- [#14866](https://github.com/spree/spree/pull/14866) [`cbde8fe`](https://github.com/spree/spree/commit/cbde8fef8d27b91ef0cc415f3a7f69135b52113a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `directUploads.create()` is replaced by `files.create()` and `files.upload()`, which uploads a file and resolves to a `signed_id` in one call, either straight to storage or in the request itself. The `signed_id` expires after a day. Every parameter that takes one is now named `signed_id` or `<slot>_signed_id` (`avatar_signed_id`, `logo_signed_id`, `attachment_signed_id`, `document_signed_id`, `file_signed_id`, `po_document_signed_id`, …). In `@spree/dashboard-core`, `useDirectUpload` becomes `useFileUpload({ visibility })`, and `signedIdParam` builds the three-state write for an image or document field.

- [#14885](https://github.com/spree/spree/pull/14885) [`34b80f0`](https://github.com/spree/spree/commit/34b80f0db561300db3e6982543c7ec724e2f4c03) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `formatMoney(amount, currency, locale?, { unitPrice? })`, which formats a decimal-string amount in its currency and the reader's language with the currency's own decimal places, without passing it through a JavaScript number. The dashboard now uses the SDK's copy.

- [#14887](https://github.com/spree/spree/pull/14887) [`9b5911d`](https://github.com/spree/spree/commit/9b5911d12649671ce9896f28473a2940f9a1cba0) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Country and currency names move to the client: the Store API's country `name` and currency `name` and `symbol` are deprecated (name them with `Intl.DisplayNames`, format amounts with `formatMoney`), and the Admin and Seller APIs no longer return a country's `name`. The seller SDK's `SellerCountry` is now the generated `Country` type, and the setup country list's `locales` are typed as `LocaleCode[]`. The dashboard and seller panel name and sort countries in the admin's own language.

  In `@spree/dashboard-core`, `CountryOption` no longer has `name` and `countryFilter` is removed: name countries with `useCountryDisplayName` and sort them with the new `useSortByCountryName`, which collates in the admin's language.

- [#14852](https://github.com/spree/spree/pull/14852) [`525959d`](https://github.com/spree/spree/commit/525959de11cf10af12fc0936f908ab3af000857f) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Money is a decimal string written to its currency's decimals, and Admin and Seller writes take money and rates only as decimal strings. Added `sumMoney`, `subtractMoney`, `multiplyMoney`, `negateMoney`, `compareMoney`, `isZeroMoney`, `isDecimalString` and `decimalPlaces` for exact arithmetic on those strings. Currencies carry `decimal_places`; prices no longer carry `amount_in_cents` or `compare_at_amount_in_cents`; tax rates read and write `rate` and `rate_percent` instead of `amount` and `amount_percentage`.

- [#14879](https://github.com/spree/spree/pull/14879) [`f184f25`](https://github.com/spree/spree/commit/f184f25097c94977eb930ac34dcbac98ff8ced7d) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Methods that delete a record are named `delete` in both SDKs. In the Seller SDK, `taxIdentifiers.remove`, `team.remove` and `invitations.revoke` are now `taxIdentifiers.delete`, `team.delete` and `invitations.delete`. In the Admin SDK, `sellers.team.remove` and `sellers.invitations.remove` are now `sellers.team.delete` and `sellers.invitations.delete`. Methods that detach something from a cart or order (`remove`), or change a record without deleting it (`revoke`), keep their names.

  Seller SDK types are corrected: `team.invite` returns the `Invitation`, and `auth.providers` returns `AuthProvidersResponse`.

- [#14858](https://github.com/spree/spree/pull/14858) [`a90a9cc`](https://github.com/spree/spree/commit/a90a9ccc68caff9349af1c0a888e6497f72d7228) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Every filterable list method now takes typed filter and sort parameters, including returns, claims, exchanges, custom fields, digital links, payouts, imports and the rest that still accepted any key. The building block for custom field value filters is now `CustomFieldValueFilters`, so it no longer hides the generated filters for custom field lists. The product digital files list now pages by 25 as intended.

- [#14854](https://github.com/spree/spree/pull/14854) [`90af080`](https://github.com/spree/spree/commit/90af080e5e3745423475ef9deef21f4dfc0bb71b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - List methods of documented endpoints now accept typed filter and sort parameters, generated from the filters each endpoint actually accepts; methods of endpoints the API reference does not document yet keep loose parameters. A misspelled filter, a filter the endpoint does not support, or an unknown sort field is now a type error instead of a request that silently returns the unfiltered list. `ProductListParams`, `CategoryListParams`, `CollectionListParams` and `OrderListParams` keep their names and are now generated; they no longer accept arbitrary keys. Filters an app adds through its own extensions can be sent unchecked inside `q` (`list({ q: { erp_id_eq: 'ERP-1' } })`), generated as declarations with `spree filters types`, or declared by hand by extending `<Resource>FilterExtensions` and `<Resource>SortExtensions`. The filter building blocks (`TextFilters`, `SortKey`, …) are exported for those declarations.

  The dashboard's allowed-origins search, delivery zones by profile, and several filters and sorts on payment methods, sellers, option types, markets, custom field definitions and gift cards now take effect; the API used to ignore them.

- [#14876](https://github.com/spree/spree/pull/14876) [`5c1eeee`](https://github.com/spree/spree/commit/5c1eeee6b5f2570c34271bcd8fd6c93fa6dbe36e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Request types that served both create and update are split by action, so creating marks what the API requires (a company's or tax rate's name, a tax registration's kind and value, an address's name, street, city and country) while updating takes any field. `AddressParams` and `CompanyAddressParams` in `@spree/sdk` stay as deprecated aliases until 6.1. The Admin SDK's `orders.payments.capture(orderId, id, params?, options?)` takes an optional `{ amount }` for a partial capture; request options move from the third argument to the fourth.

  A tax exemption certificate's `issued_at`, `expires_at` and `verified_at` are typed `string | null`: a certificate that is still pending has no dates yet.

- [#14853](https://github.com/spree/spree/pull/14853) [`3001ebf`](https://github.com/spree/spree/commit/3001ebf19fa8c361f13a7d627384d4d86a829787) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed preferences to a typed contract. Every `/…/types` entry returns `schema`, the JSON Schema of the type's `preferences`, instead of `preference_schema`, and rows no longer repeat it; `PreferenceField` and `DeliveryPreferenceField` are replaced by `PreferenceSchema`. Each configurable family's settings are typed per `type` (`PromotionRulePreferencesMap`, `TypedPromotionRule`, …), and an extension adds its own by declaration merging. Store, channel, import and seller profile settings drop the `preferred_` prefix (`guest_checkout`, `timezone`, `delimiter`), the store's decimal settings are strings, and delivery methods read and write `calculator: { type, preferences }`. Preference writes are validated, refused with `invalid_preferences` and a JSON pointer per failing value. `paymentMethods.types()` lists every provider with `installed` set on those the store already has.

- [#14871](https://github.com/spree/spree/pull/14871) [`6990f37`](https://github.com/spree/spree/commit/6990f3730ffad5245dd116b458a7b8ceeb67d310) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Request body types are now generated from the API itself, so every create, update and action method takes exactly the fields its endpoint accepts. Fields the API never accepted are gone from the types, and fields it accepted but the types left out are added. Renamed types keep their old names as deprecated aliases (for example `VariantPrice` is now `PriceParams`, `LineItemInput` is now `LineItemInputParams`). The dashboard now saves the store's digital download limits, which the API used to drop.

  Country and currency codes are typed as the closed `CountryCode` and `CurrencyCode` unions in both requests and responses. Deprecated fields are marked `@deprecated` in the types; the Store SDK keeps them until 6.1, while the Admin and Seller SDKs drop them (address `country_iso`/`state_abbr`, cart `number`, market `country_isos`, import `owner_type`/`owner_id`, payment method `auto_capture`).

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
