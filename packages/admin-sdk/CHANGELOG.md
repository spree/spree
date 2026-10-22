# @spree/admin-sdk

## 1.0.0-rc.5

### Minor Changes

- [#14911](https://github.com/spree/spree/pull/14911) [`3ca1f5e`](https://github.com/spree/spree/commit/3ca1f5e32f2e3cbb249d27571388e488153afd12) Thanks [@KacperMekarski](https://github.com/KacperMekarski)! - Company members can now pick their company's addresses when choosing where an order goes. Picking a company site at checkout used to be dropped without an error, because the cart only ever looked in the buyer's own address book. A new `GET /store/carts/:id/addresses` returns everything a cart may be shipped or billed to — the buyer's book plus the sites of the company set as the cart's `company_id` and the ones it inherits, limited to the countries the cart's market sells to — and `client.carts.addresses.list()` reaches it. The company has to be set on the cart explicitly: a buyer who belongs to a single company is not assumed to be buying for it when it comes to addresses. Every `Address` now carries the `owner` it is filed under (`null` for an address in no book, such as the copy a placed order keeps), so a picker can label the two books from one response. On the Admin API this `owner` object replaces the separate `owner_id` and `owner_type` fields. Unlike the other cart endpoints this one needs a signed-in customer: it answers with the account's address books rather than the cart's own contents. Staff get the same reach: a company's sites are selectable when creating an order, and "use default addresses" takes the company's defaults for a company order. On a division's page, addresses inherited from the companies above it are labelled with their owner and cannot be edited there.

- [#14939](https://github.com/spree/spree/pull/14939) [`9c73a79`](https://github.com/spree/spree/commit/9c73a7908dbe35ecb0b3ce654f1b3d6705e9a0c3) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added custom field editing to variants, option types, sellers, promotions, gift cards, store credits, stock transfers, purchase orders, companies, payment methods, delivery methods, tax rates, product types, media and store settings. Sheets show the custom fields card only once the store defines a field for that type. On the product page, variant and media custom fields save with the sheet's Done, and widgets in their `product.variant.form_fields` and `product.media.form_fields` slots can save on Done through `onSave`. `FormActions` and `useFormSubmitShortcut` accept `dirty` for unsaved changes held outside the form. `client.customFields(ownerType, ownerId)` accepts each of these types.

- [#14937](https://github.com/spree/spree/pull/14937) [`90f8f59`](https://github.com/spree/spree/commit/90f8f59209dbf287520236ca6b9eab510df9f3b9) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - New draft orders take a market, sales channel, currency and locale, chosen before any item is added. A market fixes the currency and the locales on offer. The item search on a new or existing draft order lists only what the buyer can be sold on that channel, priced as they would pay in that market; `variants.list()` accepts `order_id`, or `market_id`, `channel_id`, `customer_id`, `company_id` and `currency` for an order not yet created. `order_id` cannot be combined with the other fields, and `currency` on its own also narrows the list. Order creation refuses items the buyer cannot order on the channel, and picks a market selling the requested currency when none is named. Changing any of these after items are picked asks before removing them.

### Patch Changes

- [#14933](https://github.com/spree/spree/pull/14933) [`1a86817`](https://github.com/spree/spree/commit/1a86817598711e5383d9acd663bbe808448a9dd2) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Order filter and sort types include `market_id` and `locale`. Locale, currency and country filters (`locale`, `currency`, `cost_currency`, `country_code`, `country_of_origin`) accept only `LocaleCode`, `CurrencyCode` and `CountryCode` values (new `CodeFilters` type) instead of free text.

- [#14934](https://github.com/spree/spree/pull/14934) [`dc2f1a7`](https://github.com/spree/spree/commit/dc2f1a786e4a11d6e36475ff9f7c5296ab817b14) Thanks [@mad-eel](https://github.com/mad-eel)! - A customer's own data request now waits for confirmation from the account's email address. `client.customer.dataRequests` lists, reads and opens requests, and `create` takes a `redirect_url` for the page the emailed link opens. `client.dataRequests.confirm(token)` confirms one from that page, and `client.dataRequests.get(token)` reads it, with the download link once the export is ready. `DataRequestStatus` gains `awaiting_confirmation` and `lapsed`. The dashboard's email editor lists the new confirmation email.

- [#14944](https://github.com/spree/spree/pull/14944) [`a0e5b66`](https://github.com/spree/spree/commit/a0e5b66419569d1e91d3b1eaf180444b73c65cd1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added every status, kind and other value list the Spree API returns to `@spree/core`, each as a list of its values (`PRODUCT_STATUSES`, `MEDIA_TYPES`, …) and a type (`ProductStatus`, `MediaType`, …) — open where extensions may add values, closed otherwise — plus `subsetOf` for picking the values an action accepts with each one checked at compile time. The SDKs re-export these types instead of each carrying its own copy, so their names and values are unchanged. The dashboards and the seller panel build their status filters and action checks from these lists, so a status added on the server shows up without a dashboard change. Value lists the SDKs used to spell out inline, such as a seller transfer's `kind`, now have names of their own; `MediaType`, `CollectionRuleMatchPolicy` and `CollectionSortOrder` in `@spree/admin-sdk`, and `ClaimResolution` in `@spree/dashboard-ui`, now come from the generated lists under the same names. A seller's `tax_remittance` and `payouts_schedule_interval`, a claim's `resolution`, a collection's `sort_order`, a shipping label's `format`, purchase order and stock transfer statuses, and tax and commission lines' `taxability_reason` are now typed with their lists instead of as plain strings.

- [#14936](https://github.com/spree/spree/pull/14936) [`06fc8b0`](https://github.com/spree/spree/commit/06fc8b06574742b63f15e355ea352f67655459c1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Weight and dimension units are closed code lists, exported as `WeightUnit` and `DimensionUnit` (values and types) like `CountryCode` and `CurrencyCode`, and every unit field in responses and request types uses them; unit fields in requests accept `null` to fall back to the store default. The Admin and Seller SDKs publish one `VariantParams` type: `ProductVariantParams`, `VariantCreateParams` and `VariantUpdateParams` build on it. The Seller SDK's `SellerProductVariantParams` is renamed to `ProductVariantParams` (the old name stays as a deprecated alias). The variant editor and bulk variant editor now offer feet as a dimension unit.

## 1.0.0-rc.4

### Minor Changes

- [#14912](https://github.com/spree/spree/pull/14912) [`67c98ac`](https://github.com/spree/spree/commit/67c98ac10479069632f8c085a2ccbcd0741ad6d6) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `stockReservations.list`, `consentRecords.list`, `dataRequests.list`, `dataRequests.create` and `sellers.customFields`, so every Admin API endpoint can be called through the SDK. Every endpoint in the Admin API reference now also shows an SDK example.

- [#14833](https://github.com/spree/spree/pull/14833) [`b38df6e`](https://github.com/spree/spree/commit/b38df6ef3efce15705cb23c2774eb301021861d5) Thanks [@mad-eel](https://github.com/mad-eel)! - Tax rates no longer have `included_in_price`, in responses, create and update params, filters or sort. Whether prices include tax is now the market's `tax_inclusive` setting.

- [#14900](https://github.com/spree/spree/pull/14900) [`11b9a03`](https://github.com/spree/spree/commit/11b9a03c775fce616a9cd73cb39fa47e7b88bb13) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `CountryCode`, `CurrencyCode` and `LocaleCode` as values as well as types, so you can write `CurrencyCode.USD`, list every code with `Object.values(CurrencyCode)` and see each code's name in your editor. Plain strings such as `'USD'` still type-check.

- [#14916](https://github.com/spree/spree/pull/14916) [`a7aa0e5`](https://github.com/spree/spree/commit/a7aa0e51f1e7eb7847efcef27b12e53913a5defd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Admin API payments now include `avs_risky` and `cvv_risky`, and can expand `capture_events`, each capture of the money the payment authorized. On the order page, a payment whose card failed the issuer's checks is flagged, and each payment's menu opens a details dialog with the address and security code check results and the list of captures.

- [#14913](https://github.com/spree/spree/pull/14913) [`9688d11`](https://github.com/spree/spree/commit/9688d11a6033d310557080da9ff5208433eee495) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Admin API payments now include `gateway_dashboard_payment_url`, a link to the payment in the payment provider's own dashboard. On the order page, each payment's menu shows a "View at {payment method}" link when the provider offers one, so staff can look up the full payment details there.

- [#14922](https://github.com/spree/spree/pull/14922) [`214c5aa`](https://github.com/spree/spree/commit/214c5aa64bb78fe1ff88696c4f62fe94187c1622) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `taxExemptionReasons`, the store's own list of reasons a business can give for buying without tax, with list, get, create, update and delete. Each reason has a `code` the tax engine receives. Tax exemption certificates now point at a reason with `tax_exemption_reason_id` instead of recording `reason_code`, and can expand `tax_exemption_reason`. `taxProviders.list()` is now typed (`TaxProviderOption`) and says which exemption reason codes each engine reads. The dashboard gains one Settings → Taxes page with tabs for tax categories, tax rates and exemption reasons, which also shows the tax service each market uses; the certificate form offers the store's reasons.

### Patch Changes

- [#14905](https://github.com/spree/spree/pull/14905) [`e7d276d`](https://github.com/spree/spree/commit/e7d276dbc5c36c03466cefd0d40d439135d4c464) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The email branding preview now shows a newly uploaded or removed logo before saving, and refreshes after saving. The logo now sits in the Branding section of email settings. `EmailTemplatePreviewParams` accepts `mailer_logo_signed_id`.

- [#14914](https://github.com/spree/spree/pull/14914) [`1ff3b91`](https://github.com/spree/spree/commit/1ff3b911308ccc248c946b1c27f2fe5e435b7c57) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `unit_cost` is now required on every purchase order item (`PurchaseOrderItemParams`), matching what the API already enforced. The dashboard's purchase order form now starts each line with an empty cost, so Save stays disabled until the merchant prices every line, instead of filling in zero.

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

- [#14886](https://github.com/spree/spree/pull/14886) [`6034c11`](https://github.com/spree/spree/commit/6034c11340ddc997e0287935992cc603be3d756e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added the `LocaleCode` type: the locale codes Spree accepts (every ISO 639-1 language plus regional variants such as `en-US` and `pt-BR`). Order, cart and market locales, the store's default, supported and available locales, and the matching request params now use it. The dashboard validates locale fields with the new `localeCodeSchema`.

  The Store API's locale `name` is deprecated (name a locale from its `code` with `Intl.DisplayNames`) and the Admin API no longer returns it, so the admin SDK's `Locale` type drops `name` and types `code` as `LocaleCode`; the dashboard names locales in the browser.

- [#14852](https://github.com/spree/spree/pull/14852) [`525959d`](https://github.com/spree/spree/commit/525959de11cf10af12fc0936f908ab3af000857f) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Money is a decimal string written to its currency's decimals, and Admin and Seller writes take money and rates only as decimal strings. Added `sumMoney`, `subtractMoney`, `multiplyMoney`, `negateMoney`, `compareMoney`, `isZeroMoney`, `isDecimalString` and `decimalPlaces` for exact arithmetic on those strings. Currencies carry `decimal_places`; prices no longer carry `amount_in_cents` or `compare_at_amount_in_cents`; tax rates read and write `rate` and `rate_percent` instead of `amount` and `amount_percentage`.

- [#14877](https://github.com/spree/spree/pull/14877) [`8dbe607`](https://github.com/spree/spree/commit/8dbe607bdd0c66ecebadb383ea9765ba3a971cbd) Thanks [@KacperMekarski](https://github.com/KacperMekarski)! - `orders.get` now returns `Order | OrderGroup`. Called with the id of the cart a checkout was placed from, it returns the whole purchase: one order, or, when the checkout reached several sellers, the order group holding one order per seller. Narrow the result with `isOrderGroup` before reading order-only fields such as `items`. An order group now carries the same money summary as an order (delivery, discount, tax, fee, gift card and store credit totals, the amount still due) and its payments.

  `store_credit_total` on carts, orders and order groups no longer includes what a gift card paid. That amount is reported only in `gift_card_total`, so a summary that shows both rows no longer deducts it twice. `amount_due` no longer subtracts store credit that has already been captured.

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

### Patch Changes

- [#14874](https://github.com/spree/spree/pull/14874) [`293200e`](https://github.com/spree/spree/commit/293200e34b7f82c94eeaeec95fe34329956619d7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `orders.discounts.create()` takes the discount as `value` (with `value_type`); the older `amount` spelling on create is gone. `orders.discounts.update()` still edits `amount`.

- [#14864](https://github.com/spree/spree/pull/14864) [`614347a`](https://github.com/spree/spree/commit/614347a959b753efa76ed3eff145840856dc009a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The email template editor inserts an amount through the `money` filter (`{{ order.total | money }}`) instead of a pre-formatted `display_*` field. Email types gain the raw amounts the default templates now format: `total_minus_store_credits`, a line item's and a parcel item's `amount`, a parcel item's `price`, a fulfillment group's `cost` and `unpriced`, and a return's `refunded_total`.

- [#14884](https://github.com/spree/spree/pull/14884) [`9736316`](https://github.com/spree/spree/commit/9736316f970de9a8a360a5c88c9d91ef9783727a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Removed the `display_*` money fields from the `Email*` types and Zod schemas; templates format amounts with the `money` filter. Added `EmailCustomer`, `EmailCustomerGroup` and `EmailNewsletterSubscriber`, which the password reset email's `customer` variable now uses.

- [#14856](https://github.com/spree/spree/pull/14856) [`f508a38`](https://github.com/spree/spree/commit/f508a389f7f09f5ca85bfa32a2dfcec9517ea1bf) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Preferences of the new `money` type are shown with their currency's symbol in settings forms and as money in calculator summaries, instead of being guessed from the preference's name. `PreferenceField.type` documents the `money` type.

## 1.0.0-rc.1

### Minor Changes

- [#14785](https://github.com/spree/spree/pull/14785) [`aa69c35`](https://github.com/spree/spree/commit/aa69c35807f4e4801a86aec5a04917da54d6804a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `client.emailTemplates` for editing a store's customer email templates, email layout and shared partials: list and read them per language, save and discard drafts, preview with sample data, send a test email to yourself, publish, revert to Spree's default, and list or restore published revisions. Also added `EmailTemplate`, `EmailTemplateDraft`, `EmailTemplatePreview` and `EmailTemplateRevision`, and `Email*` types (`EmailOrder`, `EmailStore`, ...) describing the data each customer email template renders with.

- [#14800](https://github.com/spree/spree/pull/14800) [`fa4730a`](https://github.com/spree/spree/commit/fa4730aa458f35e70503954134a8d913c99e342d) Thanks [@mad-eel](https://github.com/mad-eel)! - `orders.fulfillments.create` accepts an optional `source_fulfillment_id`, the only fulfillment to move units from. Without it, exchange and claim replacements are never moved, so naming the parcel is how a canceled replacement is sent again.

- [#14816](https://github.com/spree/spree/pull/14816) [`06c5381`](https://github.com/spree/spree/commit/06c53811174fa687f3e250a64799bb6e9cdda8e8) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Payment methods, payment method types and integration types now carry `logo_url` and `docs_url`, the provider's logo and setup guide. Payment methods and their types also carry `third_party`, true for methods backed by an external payment provider. `PaymentMethodType` is its own interface rather than an alias of `ResourceTypeDefinition`.

- [#14837](https://github.com/spree/spree/pull/14837) [`3b80c52`](https://github.com/spree/spree/commit/3b80c52d19006dafc717e4004ec9ae4619438b7b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed every type value the APIs send or accept to a short name instead of a Ruby class name: delivery method, digital asset, payout, tax and pickup point providers (`manual`, `internal`, `system`, `file`), order routing strategies (`rules`), custom field definition `resource_type` (`product`, `category`), tag `taggable_type`, the owner and originator types on addresses, refunds and media usage, payment setup session `payment_source_type` (`credit_card`), and type filters such as `type_eq` and `receivable_type_eq`. Removed `integration_class` from the provider listings and the deprecated custom field `type` field (use `field_type`), and corrected the shipping label `owner_type` type to `'fulfillment' | 'return'`.

- [#14799](https://github.com/spree/spree/pull/14799) [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da) Thanks [@mad-eel](https://github.com/mad-eel)! - Returns, claims and exchanges now give back the tax the customer paid. Return lines carry `included_tax_total`, `additional_tax_total`, `tax_total` and `refund_amount` (tax included), and returns carry `refund_tax_total`. On a store whose prices include VAT, a return line's `pre_tax_amount` now reads the price before tax rather than the gross price. Claim and exchange lines carry the tax on each half, tax lines name the return, claim or exchange line they belong to and whether they are a `credit`, Admin refunds carry `tax_amount`, and Seller order line items carry `additional_tax_total`. Fees gain the `exchange` kind.

- [#14799](https://github.com/spree/spree/pull/14799) [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da) Thanks [@mad-eel](https://github.com/mad-eel)! - Admin returns carry `display_refunded_total`. A refunded return's card in the dashboard and the seller panel now shows what was actually refunded instead of what the return was worth, and names both when less went back, for example "Refunded $25.00 of $30.26".

- [#14773](https://github.com/spree/spree/pull/14773) [`8f21572`](https://github.com/spree/spree/commit/8f21572de3aff53fa8bb3fd5931f1b44307e7936) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added typed webhook events. `@spree/sdk/webhooks` now maps every event Spree publishes to the record its `data` carries, so checking `event.name` narrows `event.data`, and `constructWebhookEvent` verifies a request and returns the typed event (optionally validated with `webhookEventSchemas` from `@spree/sdk/zod`). `WebhookEvent<Order>` keeps working but is deprecated in favour of `WebhookEvent<'order.placed'>`. The Admin SDK adds `client.webhookEvents.list()`, and the dashboard's webhook event picker now reads that list instead of a hand-kept one.

- [#14763](https://github.com/spree/spree/pull/14763) [`53d9925`](https://github.com/spree/spree/commit/53d9925440d62343d77efad3c8dc849c4fa54008) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added runtime Zod schemas to the Admin and Seller SDKs, exported from `@spree/admin-sdk/zod` and `@spree/seller-sdk/zod`, matching what `@spree/sdk/zod` already offers for the Store API. Schemas for inline objects, unions and records are now precise instead of accepting any value, which also tightens a few Store SDK schemas (cart warnings, payment sources, product filters).

### Patch Changes

- [#14839](https://github.com/spree/spree/pull/14839) [`446d3cb`](https://github.com/spree/spree/commit/446d3cbc71b3ff980d48559317089e13eaab564e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed permission subjects to short names: `/me` returns `product`, `category`, `customer` instead of Ruby class names, and the `Subject` constants, `<Can>` checks and navigation `subject` entries use the same names. Plugins that pass class names (`'Spree::Order'`) to `permissions.can`, `<Can>` or a navigation entry must switch to the short name (`'order'`) or a `Subject` constant. Category checks now work for roles without full access.

## 1.0.0-beta.3

### Minor Changes

- [#14736](https://github.com/spree/spree/pull/14736) [`e601826`](https://github.com/spree/spree/commit/e601826eb3cc701bc918ae7ddb9c2c52598e02d7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Invitation listings no longer include `acceptance_url`, because the link carries the token that accepts the invitation. Fetch it on demand with `invitations.acceptanceLink(id)` (and `sellers.invitations.acceptanceLink(sellerId, id)` in the Admin SDK), which needs write access. The "Copy invitation link" actions in the dashboard and the seller panel now use it.

### Patch Changes

- [#14702](https://github.com/spree/spree/pull/14702) [`349dddf`](https://github.com/spree/spree/commit/349dddfb537dad5b82aa50a2409bd3d0d0918756) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `orders.create` and `orders.update` params now include `company_id`, which the Admin API already accepted. Sending it makes a draft a company purchase; `null` on update clears it.

- [#14696](https://github.com/spree/spree/pull/14696) [`d065d0b`](https://github.com/spree/spree/commit/d065d0b793046cacc671f0d5297990b9ac600ab7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `orders.refunds.create` no longer accepts `reason_id`. The Admin API only reads `refund_reason_id` (matching the `Refund` response field), so a `reason_id` was silently dropped and the refund fell back to the store's first refund reason. The params are now typed as `RefundCreateParams`; pass `refund_reason_id` instead.

- [#14703](https://github.com/spree/spree/pull/14703) [`9e41f7d`](https://github.com/spree/spree/commit/9e41f7da03a9fd87050a78033620225922574d14) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The `refund_reason_id` documentation now shows the refund reason ID prefix Spree actually uses (`rr_…`).

- [#14727](https://github.com/spree/spree/pull/14727) [`a862b80`](https://github.com/spree/spree/commit/a862b80014fc5aa8ecddca1008917eda9f17635f) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The dashboard now refers to customers by their 6.0 class name, `Spree::Customer`, instead of the pre-6.0 `Spree::User`. This fixes the Customers list's Tags filter, which always showed "No results", along with customer permission checks and customer custom fields. `client.customFields('Spree::Customer', id)` is now supported; `'Spree::User'` keeps working until 6.1.

## 1.0.0-beta.2

### Patch Changes

- [#14671](https://github.com/spree/spree/pull/14671) [`20b5c2e`](https://github.com/spree/spree/commit/20b5c2e4fd50a83865d119e412caad1d2ad3bdad) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Accept `preferred_always_include_confirm_step` when updating a store.

- [#14644](https://github.com/spree/spree/pull/14644) [`6723b99`](https://github.com/spree/spree/commit/6723b99bdf8453f6e3a2a6666211f69d658f566e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `auth.completeSetup` accepts `sample_data`, which queues the demo catalog load once the admin account exists.

## 1.0.0-beta.1

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
