# @spree/dashboard

## 1.0.0-rc.5

### Minor Changes

- [#14911](https://github.com/spree/spree/pull/14911) [`3ca1f5e`](https://github.com/spree/spree/commit/3ca1f5e32f2e3cbb249d27571388e488153afd12) Thanks [@KacperMekarski](https://github.com/KacperMekarski)! - Company members can now pick their company's addresses when choosing where an order goes. Picking a company site at checkout used to be dropped without an error, because the cart only ever looked in the buyer's own address book. A new `GET /store/carts/:id/addresses` returns everything a cart may be shipped or billed to — the buyer's book plus the sites of the company set as the cart's `company_id` and the ones it inherits, limited to the countries the cart's market sells to — and `client.carts.addresses.list()` reaches it. The company has to be set on the cart explicitly: a buyer who belongs to a single company is not assumed to be buying for it when it comes to addresses. Every `Address` now carries the `owner` it is filed under (`null` for an address in no book, such as the copy a placed order keeps), so a picker can label the two books from one response. On the Admin API this `owner` object replaces the separate `owner_id` and `owner_type` fields. Unlike the other cart endpoints this one needs a signed-in customer: it answers with the account's address books rather than the cart's own contents. Staff get the same reach: a company's sites are selectable when creating an order, and "use default addresses" takes the company's defaults for a company order. On a division's page, addresses inherited from the companies above it are labelled with their owner and cannot be edited there.

- [#14939](https://github.com/spree/spree/pull/14939) [`9c73a79`](https://github.com/spree/spree/commit/9c73a7908dbe35ecb0b3ce654f1b3d6705e9a0c3) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added custom field editing to variants, option types, sellers, promotions, gift cards, store credits, stock transfers, purchase orders, companies, payment methods, delivery methods, tax rates, product types, media and store settings. Sheets show the custom fields card only once the store defines a field for that type. On the product page, variant and media custom fields save with the sheet's Done, and widgets in their `product.variant.form_fields` and `product.media.form_fields` slots can save on Done through `onSave`. `FormActions` and `useFormSubmitShortcut` accept `dirty` for unsaved changes held outside the form. `client.customFields(ownerType, ownerId)` accepts each of these types.

- [#14940](https://github.com/spree/spree/pull/14940) [`44b1933`](https://github.com/spree/spree/commit/44b1933854a83f505b0b901b1fd57b1aa9ac167d) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added main-column slots to the order, customer, category, collection, purchase order and stock transfer pages (`<resource>.form_main`), and `delivery_profile.form_main` and `delivery_profile.form_sidebar` to the delivery profile page. The category and collection slots also render on the new category and new collection pages, and receive `mode`.

- [#14937](https://github.com/spree/spree/pull/14937) [`90f8f59`](https://github.com/spree/spree/commit/90f8f59209dbf287520236ca6b9eab510df9f3b9) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - New draft orders take a market, sales channel, currency and locale, chosen before any item is added. A market fixes the currency and the locales on offer. The item search on a new or existing draft order lists only what the buyer can be sold on that channel, priced as they would pay in that market; `variants.list()` accepts `order_id`, or `market_id`, `channel_id`, `customer_id`, `company_id` and `currency` for an order not yet created. `order_id` cannot be combined with the other fields, and `currency` on its own also narrows the list. Order creation refuses items the buyer cannot order on the channel, and picks a market selling the requested currency when none is named. Changing any of these after items are picked asks before removing them.

- [#14935](https://github.com/spree/spree/pull/14935) [`ab4f2b0`](https://github.com/spree/spree/commit/ab4f2b055e7572d2f1d717a2e71e7630b16bd4f4) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added previews of Spree Enterprise features where they appear once installed: Quotes under Orders, Onboarding under Companies, Shopify under Sellers, Lots under Inventory, and Audit log in Users & permissions settings. Companies is now its own section in the sidebar rather than sitting under Customers. Set `VITE_SPREE_ENTERPRISE_PREVIEWS=false` at build time to leave the previews out. Settings entries accept a `badge`, and plugin pages under `/settings` get the settings page padding. Registry routes can sit under a built-in section (`/sellers/shopify`) instead of being taken by its record page.

- [#14940](https://github.com/spree/spree/pull/14940) [`44b1933`](https://github.com/spree/spree/commit/44b1933854a83f505b0b901b1fd57b1aa9ac167d) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added media library slots for plugins: `media.form_fields` in a file's detail sheet, saved with its Save button, and `media.context_menu` in the grid's right-click menu. Enter in any field of the sheet now saves it.

- [#14932](https://github.com/spree/spree/pull/14932) [`af9df9f`](https://github.com/spree/spree/commit/af9df9fc1d423ca88db7761ec9467fedfda76cd1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The orders and draft orders lists can be filtered by market and locale, and show both as optional columns. Table definitions gain a `locale` filter type that lists the store's languages by name.

- [#14940](https://github.com/spree/spree/pull/14940) [`44b1933`](https://github.com/spree/spree/commit/44b1933854a83f505b0b901b1fd57b1aa9ac167d) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added product page slots for plugins: `product.form_main` at the end of the main column, `product.media.form_fields` in the media editor, `product.media.actions` in the Media card, and `product.variant.form_fields` in the variant editor, with `seller.product.*` counterparts in the seller panel. `product.form_sidebar` now also renders on the new product page, and both column slots receive `mode`. Fields on a media or variant row register under the `product.media` and `product.variant` form keys and save with the product.

- [#14940](https://github.com/spree/spree/pull/14940) [`44b1933`](https://github.com/spree/spree/commit/44b1933854a83f505b0b901b1fd57b1aa9ac167d) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `<resource>.form_fields` slots to the create and edit sheets for markets, stock locations, tax rates, tax categories, sales channels, policies, package types, product types, delivery zones, delivery methods, option types and customer groups. Fields a widget binds there save with the sheet. The seller panel's stock location and package type sheets use `seller.stock_location.form_fields` and `seller.package_type.form_fields`. `HostFormSlot` renders a slot that exposes a form which isn't wrapped in `FormProvider`.

### Patch Changes

- [#14934](https://github.com/spree/spree/pull/14934) [`dc2f1a7`](https://github.com/spree/spree/commit/dc2f1a786e4a11d6e36475ff9f7c5296ab817b14) Thanks [@mad-eel](https://github.com/mad-eel)! - A customer's own data request now waits for confirmation from the account's email address. `client.customer.dataRequests` lists, reads and opens requests, and `create` takes a `redirect_url` for the page the emailed link opens. `client.dataRequests.confirm(token)` confirms one from that page, and `client.dataRequests.get(token)` reads it, with the download link once the export is ready. `DataRequestStatus` gains `awaiting_confirmation` and `lapsed`. The dashboard's email editor lists the new confirmation email.

- [#14944](https://github.com/spree/spree/pull/14944) [`a0e5b66`](https://github.com/spree/spree/commit/a0e5b66419569d1e91d3b1eaf180444b73c65cd1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added every status, kind and other value list the Spree API returns to `@spree/core`, each as a list of its values (`PRODUCT_STATUSES`, `MEDIA_TYPES`, …) and a type (`ProductStatus`, `MediaType`, …) — open where extensions may add values, closed otherwise — plus `subsetOf` for picking the values an action accepts with each one checked at compile time. The SDKs re-export these types instead of each carrying its own copy, so their names and values are unchanged. The dashboards and the seller panel build their status filters and action checks from these lists, so a status added on the server shows up without a dashboard change. Value lists the SDKs used to spell out inline, such as a seller transfer's `kind`, now have names of their own; `MediaType`, `CollectionRuleMatchPolicy` and `CollectionSortOrder` in `@spree/admin-sdk`, and `ClaimResolution` in `@spree/dashboard-ui`, now come from the generated lists under the same names. A seller's `tax_remittance` and `payouts_schedule_interval`, a claim's `resolution`, a collection's `sort_order`, a shipping label's `format`, purchase order and stock transfer statuses, and tax and commission lines' `taxability_reason` are now typed with their lists instead of as plain strings.

- [#14936](https://github.com/spree/spree/pull/14936) [`06fc8b0`](https://github.com/spree/spree/commit/06fc8b06574742b63f15e355ea352f67655459c1) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Weight and dimension units are closed code lists, exported as `WeightUnit` and `DimensionUnit` (values and types) like `CountryCode` and `CurrencyCode`, and every unit field in responses and request types uses them; unit fields in requests accept `null` to fall back to the store default. The Admin and Seller SDKs publish one `VariantParams` type: `ProductVariantParams`, `VariantCreateParams` and `VariantUpdateParams` build on it. The Seller SDK's `SellerProductVariantParams` is renamed to `ProductVariantParams` (the old name stays as a deprecated alias). The variant editor and bulk variant editor now offer feet as a dimension unit.
- Updated dependencies [[`a0e5b66`](https://github.com/spree/spree/commit/a0e5b66419569d1e91d3b1eaf180444b73c65cd1)]:
  - @spree/core@0.2.0

## 1.0.0-rc.4

### Minor Changes

- [#14916](https://github.com/spree/spree/pull/14916) [`a7aa0e5`](https://github.com/spree/spree/commit/a7aa0e51f1e7eb7847efcef27b12e53913a5defd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Admin API payments now include `avs_risky` and `cvv_risky`, and can expand `capture_events`, each capture of the money the payment authorized. On the order page, a payment whose card failed the issuer's checks is flagged, and each payment's menu opens a details dialog with the address and security code check results and the list of captures.

- [#14913](https://github.com/spree/spree/pull/14913) [`9688d11`](https://github.com/spree/spree/commit/9688d11a6033d310557080da9ff5208433eee495) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Admin API payments now include `gateway_dashboard_payment_url`, a link to the payment in the payment provider's own dashboard. On the order page, each payment's menu shows a "View at {payment method}" link when the provider offers one, so staff can look up the full payment details there.

- [#14922](https://github.com/spree/spree/pull/14922) [`214c5aa`](https://github.com/spree/spree/commit/214c5aa64bb78fe1ff88696c4f62fe94187c1622) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `taxExemptionReasons`, the store's own list of reasons a business can give for buying without tax, with list, get, create, update and delete. Each reason has a `code` the tax engine receives. Tax exemption certificates now point at a reason with `tax_exemption_reason_id` instead of recording `reason_code`, and can expand `tax_exemption_reason`. `taxProviders.list()` is now typed (`TaxProviderOption`) and says which exemption reason codes each engine reads. The dashboard gains one Settings → Taxes page with tabs for tax categories, tax rates and exemption reasons, which also shows the tax service each market uses; the certificate form offers the store's reasons.

### Patch Changes

- [#14917](https://github.com/spree/spree/pull/14917) [`dd72579`](https://github.com/spree/spree/commit/dd72579df100ac42e46137851941f292c378172e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Apps no longer choose the versions of `@tanstack/react-table`, `@tanstack/react-hotkeys` and `@hookform/resolvers` used inside the dashboard packages: they are now regular dependencies, so upgrading them in an app (for example to React Table 9) no longer breaks type checking or the dashboard itself. Table column definitions are available as `DataGridColumn` from `@spree/dashboard-ui`. The TipTap menu extensions are pinned to the same version as the rest of the editor.
  
  `@spree/dashboard` and `@spree/seller-dashboard` now list the libraries they share with the app (React, TanStack Router and Query, React Hook Form, i18next, react-i18next and the Spree dashboard packages) as peer dependencies, so the app's copy is the only one. Before, an app on a different version got a second copy, which crashes React or makes plugins disappear. Apps must list these packages as their own dependencies; the starter templates now include React Hook Form, i18next and react-i18next.

- [#14900](https://github.com/spree/spree/pull/14900) [`11b9a03`](https://github.com/spree/spree/commit/11b9a03c775fce616a9cd73cb39fa47e7b88bb13) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Currency pickers that offer every currency now show the same list on every browser: the currencies Spree accepts that are still in use.

- [#14833](https://github.com/spree/spree/pull/14833) [`b38df6e`](https://github.com/spree/spree/commit/b38df6ef3efce15705cb23c2774eb301021861d5) Thanks [@mad-eel](https://github.com/mad-eel)! - The market form's tax switch is now "Prices include tax" and decides whether customers pay the price as entered with tax inside it or have tax added at checkout. The tax rate form and list no longer show "Included in price".

- [#14905](https://github.com/spree/spree/pull/14905) [`e7d276d`](https://github.com/spree/spree/commit/e7d276dbc5c36c03466cefd0d40d439135d4c464) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The email branding preview now shows a newly uploaded or removed logo before saving, and refreshes after saving. The logo now sits in the Branding section of email settings. `EmailTemplatePreviewParams` accepts `mailer_logo_signed_id`.

- [#14914](https://github.com/spree/spree/pull/14914) [`1ff3b91`](https://github.com/spree/spree/commit/1ff3b911308ccc248c946b1c27f2fe5e435b7c57) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `unit_cost` is now required on every purchase order item (`PurchaseOrderItemParams`), matching what the API already enforced. The dashboard's purchase order form now starts each line with an empty cost, so Save stays disabled until the merchant prices every line, instead of filling in zero.

## 1.0.0-rc.3

### Minor Changes

- [#14856](https://github.com/spree/spree/pull/14856) [`05d6372`](https://github.com/spree/spree/commit/05d637294259a03b53e1849be6638bcb2b328d14) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The Admin and Seller APIs no longer return `display_*` money fields, so their types drop them; format the amount with its currency instead. The dashboard and seller panel format every amount in the admin's own language. `formatMoney` writes a currency's ISO 4217 decimals and takes `{ unitPrice: true }` for up to four.

- [#14859](https://github.com/spree/spree/pull/14859) [`9728851`](https://github.com/spree/spree/commit/9728851b963a288e89f00ab85bcb993d3ebf5293) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Plugins and host apps can now add pages outside a store, such as onboarding, sign-up and account pages. File routes go in the new `authenticatedRoutes` (signed-in users) or `publicRoutes` (anyone) directories of a plugin's `spree.dashboard` marker; registry routes take `scope: 'authenticated'` or `scope: 'public'` with a full URL path. Both mount at the root, outside the store layout, and a page that takes the path of a built-in page fails with an error naming it.

  The signed-in landing page at `/` can be replaced through the new `store_selection` slot, for example with a list of stores and a way to create one, and the login page renders extra content, such as a sign-up link, from the new `login.after` slot.

- [#14866](https://github.com/spree/spree/pull/14866) [`cbde8fe`](https://github.com/spree/spree/commit/cbde8fef8d27b91ef0cc415f3a7f69135b52113a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - `directUploads.create()` is replaced by `files.create()` and `files.upload()`, which uploads a file and resolves to a `signed_id` in one call, either straight to storage or in the request itself. The `signed_id` expires after a day. Every parameter that takes one is now named `signed_id` or `<slot>_signed_id` (`avatar_signed_id`, `logo_signed_id`, `attachment_signed_id`, `document_signed_id`, `file_signed_id`, `po_document_signed_id`, …). In `@spree/dashboard-core`, `useDirectUpload` becomes `useFileUpload({ visibility })`, and `signedIdParam` builds the three-state write for an image or document field.

- [#14853](https://github.com/spree/spree/pull/14853) [`3001ebf`](https://github.com/spree/spree/commit/3001ebf19fa8c361f13a7d627384d4d86a829787) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed preferences to a typed contract. Every `/…/types` entry returns `schema`, the JSON Schema of the type's `preferences`, instead of `preference_schema`, and rows no longer repeat it; `PreferenceField` and `DeliveryPreferenceField` are replaced by `PreferenceSchema`. Each configurable family's settings are typed per `type` (`PromotionRulePreferencesMap`, `TypedPromotionRule`, …), and an extension adds its own by declaration merging. Store, channel, import and seller profile settings drop the `preferred_` prefix (`guest_checkout`, `timezone`, `delimiter`), the store's decimal settings are strings, and delivery methods read and write `calculator: { type, preferences }`. Preference writes are validated, refused with `invalid_preferences` and a JSON pointer per failing value. `paymentMethods.types()` lists every provider with `installed` set on those the store already has.

### Patch Changes

- [#14864](https://github.com/spree/spree/pull/14864) [`614347a`](https://github.com/spree/spree/commit/614347a959b753efa76ed3eff145840856dc009a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The email template editor inserts an amount through the `money` filter (`{{ order.total | money }}`) instead of a pre-formatted `display_*` field. Email types gain the raw amounts the default templates now format: `total_minus_store_credits`, a line item's and a parcel item's `amount`, a parcel item's `price`, a fulfillment group's `cost` and `unpriced`, and a return's `refunded_total`.

- [#14884](https://github.com/spree/spree/pull/14884) [`9736316`](https://github.com/spree/spree/commit/9736316f970de9a8a360a5c88c9d91ef9783727a) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Removed the `display_*` money fields from the `Email*` types and Zod schemas; templates format amounts with the `money` filter. Added `EmailCustomer`, `EmailCustomerGroup` and `EmailNewsletterSubscriber`, which the password reset email's `customer` variable now uses.

- [#14885](https://github.com/spree/spree/pull/14885) [`34b80f0`](https://github.com/spree/spree/commit/34b80f0db561300db3e6982543c7ec724e2f4c03) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added `formatMoney(amount, currency, locale?, { unitPrice? })`, which formats a decimal-string amount in its currency and the reader's language with the currency's own decimal places, without passing it through a JavaScript number. The dashboard now uses the SDK's copy.

- [#14887](https://github.com/spree/spree/pull/14887) [`9b5911d`](https://github.com/spree/spree/commit/9b5911d12649671ce9896f28473a2940f9a1cba0) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Country and currency names move to the client: the Store API's country `name` and currency `name` and `symbol` are deprecated (name them with `Intl.DisplayNames`, format amounts with `formatMoney`), and the Admin and Seller APIs no longer return a country's `name`. The seller SDK's `SellerCountry` is now the generated `Country` type, and the setup country list's `locales` are typed as `LocaleCode[]`. The dashboard and seller panel name and sort countries in the admin's own language.

  In `@spree/dashboard-core`, `CountryOption` no longer has `name` and `countryFilter` is removed: name countries with `useCountryDisplayName` and sort them with the new `useSortByCountryName`, which collates in the admin's language.

- [#14886](https://github.com/spree/spree/pull/14886) [`6034c11`](https://github.com/spree/spree/commit/6034c11340ddc997e0287935992cc603be3d756e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added the `LocaleCode` type: the locale codes Spree accepts (every ISO 639-1 language plus regional variants such as `en-US` and `pt-BR`). Order, cart and market locales, the store's default, supported and available locales, and the matching request params now use it. The dashboard validates locale fields with the new `localeCodeSchema`.

  The Store API's locale `name` is deprecated (name a locale from its `code` with `Intl.DisplayNames`) and the Admin API no longer returns it, so the admin SDK's `Locale` type drops `name` and types `code` as `LocaleCode`; the dashboard names locales in the browser.

- [#14852](https://github.com/spree/spree/pull/14852) [`3525c00`](https://github.com/spree/spree/commit/3525c00440076a17cce671f3e20801309d8ba586) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Money fields are now shown and read in the number format of the person using the dashboard, whatever the currency or market: an admin whose dashboard is in German types `1.234,56` for dollars and euros alike. Previously the format followed the currency's market, which was ambiguous when two markets shared a currency. `useFormCurrencyLocale` and the panel client's `markets` entry are removed; use `useMoneyLocale()`.

- [#14856](https://github.com/spree/spree/pull/14856) [`f508a38`](https://github.com/spree/spree/commit/f508a389f7f09f5ca85bfa32a2dfcec9517ea1bf) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Preferences of the new `money` type are shown with their currency's symbol in settings forms and as money in calculator summaries, instead of being guessed from the preference's name. `PreferenceField.type` documents the `money` type.

- [#14869](https://github.com/spree/spree/pull/14869) [`bf1f47d`](https://github.com/spree/spree/commit/bf1f47daaca69e9262e63bced762c350206395a5) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Purchase order documents on orders can now be Excel, OpenDocument or CSV spreadsheets, as well as PDFs, images and Word documents.

- [#14879](https://github.com/spree/spree/pull/14879) [`f184f25`](https://github.com/spree/spree/commit/f184f25097c94977eb930ac34dcbac98ff8ced7d) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Methods that delete a record are named `delete` in both SDKs. In the Seller SDK, `taxIdentifiers.remove`, `team.remove` and `invitations.revoke` are now `taxIdentifiers.delete`, `team.delete` and `invitations.delete`. In the Admin SDK, `sellers.team.remove` and `sellers.invitations.remove` are now `sellers.team.delete` and `sellers.invitations.delete`. Methods that detach something from a cart or order (`remove`), or change a record without deleting it (`revoke`), keep their names.

  Seller SDK types are corrected: `team.invite` returns the `Invitation`, and `auth.providers` returns `AuthProvidersResponse`.

- [#14858](https://github.com/spree/spree/pull/14858) [`a90a9cc`](https://github.com/spree/spree/commit/a90a9ccc68caff9349af1c0a888e6497f72d7228) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Every filterable list method now takes typed filter and sort parameters, including returns, claims, exchanges, custom fields, digital links, payouts, imports and the rest that still accepted any key. The building block for custom field value filters is now `CustomFieldValueFilters`, so it no longer hides the generated filters for custom field lists. The product digital files list now pages by 25 as intended.

- [#14854](https://github.com/spree/spree/pull/14854) [`90af080`](https://github.com/spree/spree/commit/90af080e5e3745423475ef9deef21f4dfc0bb71b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - List methods of documented endpoints now accept typed filter and sort parameters, generated from the filters each endpoint actually accepts; methods of endpoints the API reference does not document yet keep loose parameters. A misspelled filter, a filter the endpoint does not support, or an unknown sort field is now a type error instead of a request that silently returns the unfiltered list. `ProductListParams`, `CategoryListParams`, `CollectionListParams` and `OrderListParams` keep their names and are now generated; they no longer accept arbitrary keys. Filters an app adds through its own extensions can be sent unchecked inside `q` (`list({ q: { erp_id_eq: 'ERP-1' } })`), generated as declarations with `spree filters types`, or declared by hand by extending `<Resource>FilterExtensions` and `<Resource>SortExtensions`. The filter building blocks (`TextFilters`, `SortKey`, …) are exported for those declarations.

  The dashboard's allowed-origins search, delivery zones by profile, and several filters and sorts on payment methods, sellers, option types, markets, custom field definitions and gift cards now take effect; the API used to ignore them.

- [#14876](https://github.com/spree/spree/pull/14876) [`5c1eeee`](https://github.com/spree/spree/commit/5c1eeee6b5f2570c34271bcd8fd6c93fa6dbe36e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Request types that served both create and update are split by action, so creating marks what the API requires (a company's or tax rate's name, a tax registration's kind and value, an address's name, street, city and country) while updating takes any field. `AddressParams` and `CompanyAddressParams` in `@spree/sdk` stay as deprecated aliases until 6.1. The Admin SDK's `orders.payments.capture(orderId, id, params?, options?)` takes an optional `{ amount }` for a partial capture; request options move from the third argument to the fourth.

  A tax exemption certificate's `issued_at`, `expires_at` and `verified_at` are typed `string | null`: a certificate that is still pending has no dates yet.

- [#14871](https://github.com/spree/spree/pull/14871) [`6990f37`](https://github.com/spree/spree/commit/6990f3730ffad5245dd116b458a7b8ceeb67d310) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Request body types are now generated from the API itself, so every create, update and action method takes exactly the fields its endpoint accepts. Fields the API never accepted are gone from the types, and fields it accepted but the types left out are added. Renamed types keep their old names as deprecated aliases (for example `VariantPrice` is now `PriceParams`, `LineItemInput` is now `LineItemInputParams`). The dashboard now saves the store's digital download limits, which the API used to drop.

  Country and currency codes are typed as the closed `CountryCode` and `CurrencyCode` unions in both requests and responses. Deprecated fields are marked `@deprecated` in the types; the Store SDK keeps them until 6.1, while the Admin and Seller SDKs drop them (address `country_iso`/`state_abbr`, cart `number`, market `country_isos`, import `owner_type`/`owner_id`, payment method `auto_capture`).

- Updated dependencies [[`05d6372`](https://github.com/spree/spree/commit/05d637294259a03b53e1849be6638bcb2b328d14), [`9728851`](https://github.com/spree/spree/commit/9728851b963a288e89f00ab85bcb993d3ebf5293), [`293200e`](https://github.com/spree/spree/commit/293200e34b7f82c94eeaeec95fe34329956619d7), [`614347a`](https://github.com/spree/spree/commit/614347a959b753efa76ed3eff145840856dc009a), [`9736316`](https://github.com/spree/spree/commit/9736316f970de9a8a360a5c88c9d91ef9783727a), [`cbde8fe`](https://github.com/spree/spree/commit/cbde8fef8d27b91ef0cc415f3a7f69135b52113a), [`34b80f0`](https://github.com/spree/spree/commit/34b80f0db561300db3e6982543c7ec724e2f4c03), [`9b5911d`](https://github.com/spree/spree/commit/9b5911d12649671ce9896f28473a2940f9a1cba0), [`6034c11`](https://github.com/spree/spree/commit/6034c11340ddc997e0287935992cc603be3d756e), [`525959d`](https://github.com/spree/spree/commit/525959de11cf10af12fc0936f908ab3af000857f), [`3525c00`](https://github.com/spree/spree/commit/3525c00440076a17cce671f3e20801309d8ba586), [`f508a38`](https://github.com/spree/spree/commit/f508a389f7f09f5ca85bfa32a2dfcec9517ea1bf), [`8dbe607`](https://github.com/spree/spree/commit/8dbe607bdd0c66ecebadb383ea9765ba3a971cbd), [`f184f25`](https://github.com/spree/spree/commit/f184f25097c94977eb930ac34dcbac98ff8ced7d), [`a90a9cc`](https://github.com/spree/spree/commit/a90a9ccc68caff9349af1c0a888e6497f72d7228), [`90af080`](https://github.com/spree/spree/commit/90af080e5e3745423475ef9deef21f4dfc0bb71b), [`5c1eeee`](https://github.com/spree/spree/commit/5c1eeee6b5f2570c34271bcd8fd6c93fa6dbe36e), [`3001ebf`](https://github.com/spree/spree/commit/3001ebf19fa8c361f13a7d627384d4d86a829787), [`6990f37`](https://github.com/spree/spree/commit/6990f3730ffad5245dd116b458a7b8ceeb67d310)]:
  - @spree/admin-sdk@1.0.0-rc.2
  - @spree/dashboard-core@1.0.0-rc.3
  - @spree/dashboard-ui@1.0.0-rc.3

## 1.0.0-rc.2

### Patch Changes

- [#14846](https://github.com/spree/spree/pull/14846) [`dca32db`](https://github.com/spree/spree/commit/dca32dbbca0b72705f89f8afb62721d3c6486728) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Projects that install the dashboard packages from npm now get a single copy of the rich text editor library. `@spree/dashboard` no longer declares its own, looser TipTap ranges next to the exact versions in `@spree/dashboard-ui`, so a newer TipTap release can no longer install beside the pinned one and break type checking.

- [#14845](https://github.com/spree/spree/pull/14845) [`9a0a293`](https://github.com/spree/spree/commit/9a0a293e2e91dccce3024f74013ade4599bbff08) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fixed type checking in projects that install the dashboard or seller panel with pnpm. The generated route file imported the routes through the package's `node_modules` link, where TypeScript cannot find the dashboard's own dependencies, so `tsc` reported hundreds of "Cannot find module" errors. It now imports them from the installed location again. Under pnpm that location includes the package version, so an upgrade rewrites the import paths in `routeTree.gen.ts`.

- Updated dependencies [[`dca32db`](https://github.com/spree/spree/commit/dca32dbbca0b72705f89f8afb62721d3c6486728), [`9a0a293`](https://github.com/spree/spree/commit/9a0a293e2e91dccce3024f74013ade4599bbff08)]:
  - @spree/dashboard-ui@1.0.0-rc.2
  - @spree/dashboard-core@1.0.0-rc.2

## 1.0.0-rc.1

### Minor Changes

- [#14837](https://github.com/spree/spree/pull/14837) [`3b80c52`](https://github.com/spree/spree/commit/3b80c52d19006dafc717e4004ec9ae4619438b7b) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed every type value the APIs send or accept to a short name instead of a Ruby class name: delivery method, digital asset, payout, tax and pickup point providers (`manual`, `internal`, `system`, `file`), order routing strategies (`rules`), custom field definition `resource_type` (`product`, `category`), tag `taggable_type`, the owner and originator types on addresses, refunds and media usage, payment setup session `payment_source_type` (`credit_card`), and type filters such as `type_eq` and `receivable_type_eq`. Removed `integration_class` from the provider listings and the deprecated custom field `type` field (use `field_type`), and corrected the shipping label `owner_type` type to `'fulfillment' | 'return'`.

- [#14784](https://github.com/spree/spree/pull/14784) [`a4baf49`](https://github.com/spree/spree/commit/a4baf4900f24739125d8efceaba5fb7e70a7fea9) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Plugins can now add cards to more detail pages. The admin dashboard has new slots on the seller payout, catalog, price list, promotion, purchase order, stock transfer and webhook endpoint pages, and the catalog, price list and promotion pages now save extension fields bound with `useHostForm()` with the page's own Save button. The seller panel has new slots on its product, order, payout and profile pages, and its product page saves extension fields the same way, under the form key `seller.product`. The slots catalog lists every slot and the context it receives.

- [#14785](https://github.com/spree/spree/pull/14785) [`4bd1741`](https://github.com/spree/spree/commit/4bd1741677b202f11c13b792bf16e62301d2c5cd) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added an email template editor under Settings → Emails → Templates. Merchants edit the emails customers receive, the email layout and shared blocks with a code editor that suggests variables and marks problems by line, next to a live preview (desktop and mobile, email and plain text). Edits save as drafts and go live when published; drafts can be discarded, templates reverted to Spree's default, test emails sent to yourself, and earlier versions restored from the history. A banner shows when a Spree upgrade changed a default the store customized, with a side-by-side comparison. The email settings page gains a Branding card for the colors and font of customer emails, with a preview. `@spree/dashboard-ui` adds a `CodeEditor` (deep import `@spree/dashboard-ui/ui/code-editor`) and a `useDebouncedValue` hook; `@spree/dashboard-core` adds the `EmailTemplate` permission subject.

- [#14816](https://github.com/spree/spree/pull/14816) [`06c5381`](https://github.com/spree/spree/commit/06c53811174fa687f3e250a64799bb6e9cdda8e8) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Settings → Integrations is now a card gallery with tabs, and it lists third-party payment providers next to service integrations. Each card switches its integration or payment method on and off straight away, opens its setup panel, and links to the provider's setup guide when one is declared — on the card and in its setup panel.

- [#14839](https://github.com/spree/spree/pull/14839) [`446d3cb`](https://github.com/spree/spree/commit/446d3cbc71b3ff980d48559317089e13eaab564e) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Changed permission subjects to short names: `/me` returns `product`, `category`, `customer` instead of Ruby class names, and the `Subject` constants, `<Can>` checks and navigation `subject` entries use the same names. Plugins that pass class names (`'Spree::Order'`) to `permissions.can`, `<Can>` or a navigation entry must switch to the short name (`'order'`) or a `Subject` constant. Category checks now work for roles without full access.

- [#14773](https://github.com/spree/spree/pull/14773) [`8f21572`](https://github.com/spree/spree/commit/8f21572de3aff53fa8bb3fd5931f1b44307e7936) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added typed webhook events. `@spree/sdk/webhooks` now maps every event Spree publishes to the record its `data` carries, so checking `event.name` narrows `event.data`, and `constructWebhookEvent` verifies a request and returns the typed event (optionally validated with `webhookEventSchemas` from `@spree/sdk/zod`). `WebhookEvent<Order>` keeps working but is deprecated in favour of `WebhookEvent<'order.placed'>`. The Admin SDK adds `client.webhookEvents.list()`, and the dashboard's webhook event picker now reads that list instead of a hand-kept one.

### Patch Changes

- [#14776](https://github.com/spree/spree/pull/14776) [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57) Thanks [@mad-eel](https://github.com/mad-eel)! - The New claim dialog now pre-fills each line's refund with what the customer paid for those items after discounts, instead of their list price, which the claim would refuse to refund on a discounted order. The amount follows the claimed quantity until the merchant types one of their own. Code that builds the dialog's lines itself passes `discountedAmount` (the line's `discounted_amount`) in place of `price`, which `ClaimableLine` no longer accepts.

- [#14776](https://github.com/spree/spree/pull/14776) [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57) Thanks [@mad-eel](https://github.com/mad-eel)! - A received return that is owed nothing, such as a free gift sent back, now offers "Complete return" instead of "Refund". The dialog explains that no money goes back and closes the return without asking for an amount or a refund method.

- [#14818](https://github.com/spree/spree/pull/14818) [`7fa7a64`](https://github.com/spree/spree/commit/7fa7a647d5372641fa45ff6fc9c52892bf791a1c) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Added an "Issue store credit" button to Loyalty → Store Credits, so a credit can be issued to any customer without opening their profile first. The page also links to its documentation now.

- [#14799](https://github.com/spree/spree/pull/14799) [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da) Thanks [@mad-eel](https://github.com/mad-eel)! - The refund dialog says how much tax the pre-filled amount gives back, and the claim dialog pre-fills each line with the tax the customer paid on top of the price. Shipping an exchange whose replacement costs more asks first, because the difference is added to the order as a balance due, and that fee is labelled "Exchange" on the order.

- [#14795](https://github.com/spree/spree/pull/14795) [`3dcc8e9`](https://github.com/spree/spree/commit/3dcc8e9b66b840cd129a38a84bbaccfe1de18f13) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - The orders and products tables now search with the `search` filter, since the old `multi_search` alias was removed from the Admin API.

- [#14822](https://github.com/spree/spree/pull/14822) [`a44267d`](https://github.com/spree/spree/commit/a44267ddc5273bc7231d8229b56200c066f6aba9) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Store credits can now be edited and deleted from the Loyalty → Store Credits page, from each row's menu or the credit's panel, matching the gift cards page.

- [#14799](https://github.com/spree/spree/pull/14799) [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da) Thanks [@mad-eel](https://github.com/mad-eel)! - Admin returns carry `display_refunded_total`. A refunded return's card in the dashboard and the seller panel now shows what was actually refunded instead of what the return was worth, and names both when less went back, for example "Refunded $25.00 of $30.26".

- [#14747](https://github.com/spree/spree/pull/14747) [`a0151c1`](https://github.com/spree/spree/commit/a0151c15a268356f5a5ba236850b8ee7405e9ae7) Thanks [@damianlegawiec](https://github.com/damianlegawiec)! - Fixed the setup screen of a new project reloading while the merchant was filling it in. The generated route file now refers to installed packages by their stable location, and `spree add` generates it right after installing, so the first dev start has nothing to rewrite. Upgrades also no longer rewrite every line of that file, so its diff shows only the pages an upgrade added.

- Updated dependencies [[`aa69c35`](https://github.com/spree/spree/commit/aa69c35807f4e4801a86aec5a04917da54d6804a), [`fa4730a`](https://github.com/spree/spree/commit/fa4730aa458f35e70503954134a8d913c99e342d), [`06c5381`](https://github.com/spree/spree/commit/06c53811174fa687f3e250a64799bb6e9cdda8e8), [`3b80c52`](https://github.com/spree/spree/commit/3b80c52d19006dafc717e4004ec9ae4619438b7b), [`f52fc12`](https://github.com/spree/spree/commit/f52fc12c788bae7edcba264e43e5da7a6c58f25f), [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57), [`9335e9f`](https://github.com/spree/spree/commit/9335e9f694df05f2311e5f369422056080a63f57), [`4bd1741`](https://github.com/spree/spree/commit/4bd1741677b202f11c13b792bf16e62301d2c5cd), [`7fa7a64`](https://github.com/spree/spree/commit/7fa7a647d5372641fa45ff6fc9c52892bf791a1c), [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da), [`3a2a78b`](https://github.com/spree/spree/commit/3a2a78bb43f84a2da1570ebb29c197e6ae1f1c98), [`446d3cb`](https://github.com/spree/spree/commit/446d3cbc71b3ff980d48559317089e13eaab564e), [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da), [`c9d9a2f`](https://github.com/spree/spree/commit/c9d9a2f3e9f37c6a5f9c27d0825e4f505d86f4da), [`291238d`](https://github.com/spree/spree/commit/291238dfc0b05f9b322f9e51d6cd3737006ba430), [`a0151c1`](https://github.com/spree/spree/commit/a0151c15a268356f5a5ba236850b8ee7405e9ae7), [`f52fc12`](https://github.com/spree/spree/commit/f52fc12c788bae7edcba264e43e5da7a6c58f25f), [`f52fc12`](https://github.com/spree/spree/commit/f52fc12c788bae7edcba264e43e5da7a6c58f25f), [`8f21572`](https://github.com/spree/spree/commit/8f21572de3aff53fa8bb3fd5931f1b44307e7936), [`53d9925`](https://github.com/spree/spree/commit/53d9925440d62343d77efad3c8dc849c4fa54008)]:
  - @spree/admin-sdk@1.0.0-rc.1
  - @spree/dashboard-ui@1.0.0-rc.1
  - @spree/dashboard-core@1.0.0-rc.1

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
