# @spree/admin-sdk

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
  - `client.stockTransfers` is new with `list / get / create / delete`. Backed by `/api/v3/admin/stock_transfers`. The create body takes a `variants: [{ variant_id, quantity }]` array; pass `source_location_id` for a transfer between two locations or omit it to record an external vendor receive at the destination. The model fans the payload out across `stock_movements` and adjusts source/destination `count_on_hand` atomically.
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
