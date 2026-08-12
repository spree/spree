# Spree Commerce — Development Rules

## Plans & Architecture Decisions

All feature plans live in `docs/plans/` using the template at `docs/plans/_template.md`. Never create plans elsewhere.

When proposing significant architectural changes:
1. Check existing plans in `docs/plans/` for conflicts
2. Create or update a plan using the template before implementing
3. Pay special attention to "Constraints on Current Work" sections — these apply even when you're not implementing that plan directly

Use `/project:create-plan` and `/project:update-plan` for plan management.

Active plans (6.0 target, work pending):
- `6.0-multi-vendor-marketplace.md` — Open-source the marketplace core (Vendor, OrderGroup-based order splitting, commission engine with EU commission taxation, `VendorTransfer`/`VendorPayout` ledger + pluggable `PayoutProvider`) per spree/spree#13323. 6.0 headline feature; rebuilds the legacy Enterprise multi-vendor module as native models on the Cart/Order split. Basic Stripe Connect payouts (Express onboarding + on-fulfillment transfers) ship OSS in the monorepo, alongside the Stripe core gateway pulled in from the standalone `spree_stripe` repo (payment-sessions classes only, likely `spree/core` — decisions.md 2026-07-15); Enterprise keeps refund clawbacks/netting, reconciliation, KYC ops, DAC7 payout reports, facilitator taxes + Shopify/WooCommerce vendor apps.
- `6.0-cart-order-split.md` — Cart/Order model separation, dual-FK owner everywhere (`cart_id`/`order_id` exactly-one, `#owner` as method — NOT polymorphic), idempotent copy-on-completion (`Order#cart_id` unique, order-before-payment), Order state machine removed (Checkout::Requirements for steps; payment/fulfillment statuses derived-then-persisted via one recompute service). **Shipped to 6-0-dev (feature/6-0-core-rewrite Waves 1+5):** Cart owns checkout end to end, machine + `spree_orders.state` gone, `Carts::Complete` three-phase pipeline live, `Orders::UpdateStatuses` sole status writer; only Wave 7 data migration (incomplete orders → carts) remains
- `6.0-admin-api.md` — Admin REST API conventions, auth, endpoint list (~300 endpoints)
- `6.0-admin-spa.md` — React admin architecture, extension points, table registry, i18n + server-error mapping
- `6.0-admin-rbac.md` — First-class admin RBAC (spree/spree#14164; design finalized 2026-08-07): **one grant system, staff-only**. The permission catalog IS the API-key scope vocabulary (`read_*`/`write_*` per resource; `ApiKey::SCOPES` derives from the catalog; new `staff` pair split from `settings`); **permission sets are deleted at 6.0 with NO bridge** (recorded exception to the bridges convention — `assign` raises an upgrade tripwire; record-level custom rules → `register_ability`). **Roles are pure data** — no code-managed roles, no runtime merge; roles-as-code = seeds or Admin API; extensions register catalog resources, never roles. Enforcement unifies on the key gate for JWT staff AND secret keys (`ScopedAuthorization` generalized); CanCanCan demoted to internal plumbing. DB: JSON key array + `description` + `mutable` on `spree_roles` (admin seeded immutable — NamedType pattern; hosts can lock compliance roles the same way); roles CRUD + `GET /admin/permissions` + `/me.permission_keys` + 403 `details.required_permission`; full-page role editor (`/settings/roles/$roleId`) sharing one PermissionPicker with the API-keys page (client-side templates, no seeds). Storefront has NO roles — customer baseline is internal ability code, scope-fetching is the enforcement; B2B company roles are a separate future Enterprise system (never share the vocabulary); catalog visibility per group/company is data scoping, never a permission key. **Constraints now:** no new `PermissionSets::` classes or `Spree.permissions.assign` calls; models authorized by new admin controllers must be covered by a catalog entry; new sensitive resources get their own catalog resource, never ride `settings`; storefront code never consults `Spree::Role` or the catalog.
- `6.0-product-types.md` — Prototype → ProductType rename, custom-field schema enforcement. **Creation-time template (2026-08-06):** type edits never mutate existing products (custom-field form/validation + `fulfillment_types` are live by reference; option types/categories seed additively at attach; explicit previewed `ApplyToProducts` job is the only bulk path); per-product type detach/reassign allowed (non-destructive), `required` on a type's custom field is **advisory only** (dashboard marker; no server validation — Spree writes product + fields in two steps), no Store API exposure. **Fully shipped** (all phases, Phase 2 rescoped + delivered 2026-08-06)
- `6.0-remove-master-variant.md` — Eliminate is_master, add default_variant_id FK on Product. **Shipped to 6-0-dev (PR #14265):** is_master removed from all models, default_variant_id + `spree:remove_master_variant` data-migration rake landed; only the physical is_master column drop remains (6.1 cleanup).
- `6.0-typed-stock-movements.md` — Replace generic StockMovement with typed kinds + concrete FKs
- `6.0-normalize-state-to-status.md` — Rename state → status on Payment, Shipment, InventoryUnit, ReturnAuthorization, GiftCard
- `6.0-delivery-profiles.md` — **Implemented in PR #14404 (2026-08-09).** `Spree::DeliveryProfile` = ShippingCategory promoted via table rename (`spree_shipping_categories`→`spree_delivery_profiles`, `products.shipping_category_id`→`delivery_profile_id`): store-scoped STI (kinds `DeliveryProfiles::Shipping`/`::Digital` via `Spree.delivery_profile_types`), one default per store, products reference it directly and it's required (auto-assigned: type template else store default; ProductType stamps at creation only — template doctrine). Profile ↔ stock locations (origins, empty=all) + profile→zones + profile→methods; method binds ≤1 zone (m:n join dropped), optional ships-from narrowing per method (no location-group layer — considered, dropped). **Classes only, NO string vocabularies:** method `fulfillment_type` column dropped, `Spree.fulfillment_types` registry + ProductType array deleted; behavior = `FulfillmentProvider` class predicates (`digital?`/`pickup?`/`pickup_point?`/`requires_address?`), rate-provider `requires_address?`, profile kind `digital?`/`requires_shipping_address?` + composition validations. Carts split per profile (`Splitter::DeliveryProfile`); Coordinator allocates only from profile-covered locations. `spree:migrate_delivery_profiles` (5.6→6.0 manifest) does store assignment/kind detection/non-narrowing fold-in/method m:n collapse (`spree_shipping_method_categories` survives to 6.1 as source). ShippingCategory/ShippingMethodCategory classes + associations deleted. Supersedes the string-registry + "named groups 6.1" decisions.
- `6.0-fulfillment-and-delivery.md` — Shipment→Fulfillment, ShippingMethod→DeliveryMethod, drop ShippingCategory, FulfillmentProvider strategy, pickup (merchant StockLocation) + pickup_point (third-party PickupPointProvider). **Shipped to 6-0-dev (Waves 2+4+6):** renames + deprecated twins, providers (Manual/Digital/Pickup/PickupPoint), dual-emit events, store pickup discovery endpoints, admin delivery_methods/delivery_zones CRUD + dashboard settings pages, FulfillmentMailer; Wave 7 shipping→delivery data migration remains. Pickup work beyond shipped code deferred to 6.1 (2026-08-06): contract hardening (`new(delivery_method)` ctor, `find_nearby` zipcode/query) + how-to guide; `PickupPointProvider::Base` stays **undocumented in 6.0** (v6 docs cover only the delivery rate provider interface) — never add pickup-provider docs in 6.0 work. Delivery mechanics live on provider classes (`pickup_point` provider ships but stays unregistered until 6.1; `local_delivery` cut = shipping + postal-code zone); the string fulfillment-type registry was deleted by `6.0-delivery-profiles.md`. **Partial fulfillment (2026-08-10, resolved question 12):** shipping a subset is `Spree::Fulfillments::Fulfill` (optional per-line-item `items:` + `tracking:` + `notify_customer:`; splits then fulfills in one transaction) — never a state-machine event, since split-then-ship in an `after_transition` is what service-workflows prohibits. **Side effects left the machine (2026-08-10, question 13):** `after_cancel`/`after_resume` are gone as transition callbacks — restock + carrier stand-down live in `Fulfillments::Cancel`/`::Resume` as inline steps (provider call is an `external_step`; `notify_provider: false` lets `Orders::Cancel` delegate and batch carrier I/O after its own transaction), `after_cancel`/`after_resume` are deprecated shells and the only trace left on the model — never add public model methods for workflows to call. **Status model (2026-08-11, question 14): the machine is REMOVED.** `status` = plain `HasStatus` `unfulfilled → fulfilled → delivered | canceled` (`pending`/`ready`/`ready_for_pickup` collapse — payment/stock gating is a `Fulfillments::Fulfill` validate guard, pickup renders modality-aware labels); `delivered` = confirmed receipt (`Fulfillments::MarkDelivered`, `delivered_at`, `fulfillment.delivered`) — the returns window + EU withdrawal anchor; carrier truth is the separate `tracking_status` axis (data, never a machine) written by `Fulfillments::UpdateTracking`, fed by EasyPost tracker webhooks (opt-in trackers for hand-entered numbers). Rollup domain `backorder | canceled | partial | unfulfilled | fulfilled | delivered`. **Phase 7 shipped 2026-08-11** (core + API + dashboard + EasyPost tracker webhook + `spree:migrate_fulfillment_statuses`); **label leads, fulfilled follows (2026-08-12):** `Fulfillments::PurchaseLabel` = explicit pre-ship label buy (loud failure, no email); `Fulfill` buys label BEFORE marking fulfilled (email always carries tracking; post-split failure keeps the split, never rolls it back); providers declare `generates_labels?` + idempotent `create_fulfillment`. **One tracking number per fulfillment (2026-08-11, question 15):** diverging parcels are split fulfillments; a `spree_fulfillment_trackings` model is 6.1 work and must absorb the entire carrier axis (per-row status/`delivered_at`, webhook matching by row) — never split the axis across fulfillment and tracking rows
- `6.0-returns-exchanges-claims.md` — First-class Return, Exchange, Claim models replacing ReturnAuthorization/Reimbursement chain. **COMPLETE (2026-08-05):** all three entities (+ permanent `ReturnLineItem`/`ExchangeLineItem`/`ClaimLineItem` line items), `Spree::HasStatus`, all fifteen workflows (each with a leading `validate` hook), `Refund#originator`, admin + store v3 APIs (transitions as PATCH member actions; no destroy — cancel instead), dashboard pages. Legacy chain **removed**: ReturnAuthorization/CustomerReturn/Reimbursement/ReimbursementType/legacy ReturnItem + eligibility validators + ReturnsCalculator classes all deleted, but their **tables deliberately survive to 6.1** as the data migration's source and rollback path. `spree:upgrade:migrate_returns` (`Spree::ReturnsMigrator`, defined in the rake file like its sibling upgrade tasks; anonymous-AR readers) is in the 5.6→6.0 manifest after the adjustments step; it needs no cursor because the preserved `number` is uniquely indexed on the new tables, so "what's left" is a `where.not(number: ...)` query and an interrupted run resumes for free. `ReturnAuthorizationReason`→`ReturnReason` (alias one release) + new `ClaimReason`; `Metafields` on all three. Capability replacements: `Spree::ReturnMailer#refunded_email` on `return.refunded` (replaces the reimbursement email), `Order#outstanding_balance` drops the reimbursement term (refunds already net out of `payment_total`), `Return#refunded_total` counts store credits too, `StoreCreditCategory.default_refund_category` (alias kept). **Reasons** ship admin-only CRUD (`/api/v3/admin/{return,claim,refund}_reasons`, `settings` scope) + a combined Settings → Reasons dashboard page + reason pickers on the create dialogs; `mutable` is never client-writable and the immutability guard lives on `Spree::NamedType` (`can_be_deleted?` + rename/destroy guards) because secret API keys authorize by scope and never consult CanCanCan. **No state machines (2026-08-02):** plain `status` string + inclusion validation; all fifteen transitions are workflows (`Returns::Receive`, `Exchanges::Fulfill`, `Claims::Resolve`, …) with `validate` hooks for return-eligibility policy and refunds as `external_step`. Nothing happens in a model or transition callback. Statuses live in a `class_attribute` via the core `Spree::HasStatus` concern (`has_status` + additive `add_status(value, after:)`, generating predicates and scopes) — extensible by design, additive only, and no transition graph (that would be a state machine again). **Return eligibility is a hook, not a policy engine (2026-08-03):** no window/restocking-fee/final-sale flag in core — a `validate` handler decides, enforcing for customers while letting staff override (it reads `created_by`), and region-varying policy reads `order.market`. Medusa/Saleor/Vendure ship no policy at all; Shopify's engine has no API. A `ReturnPolicy` model can arrive later behind the same hook.
- `6.0-platform-auth.md` — Drop Devise, own auth stack, User→Customer/Staff rename (RefreshToken shipped in 5.4)
- `6.0-tax-provider.md` — Per-Market TaxProvider, replaces TaxRate.adjust + Calculator; TaxRate gets direct country/state FKs (tax decoupled from Zone; Zone model dropped in 6.0 via `6.0-delivery-zones.md`); reference provider: Avalara (decisions.md 2026-07-30)
- `6.0-delivery-rate-provider.md` — Per-DeliveryMethod DeliveryRateProvider wrapping Stock::Estimator (calculators stay — 2026-07-27 reversal), `store_id` on ShippingMethod; monorepo ships one reference multi-carrier provider (**EasyPost** — decisions.md 2026-08-06 reversal: BYOCA fit for larger merchants + only maintained official Ruby SDK; Shippo's ruby gem dead since 2020); method rows stay regional (no cross-market method entity). **Dynamic carrier rates (2026-08-09):** a carrier method is the carrier connection — `estimates(package)` returns one Estimate per service, each becoming its own named DeliveryRate (unique (fulfillment, method) rate index dropped; `DeliveryRate#name` falls back to the method name); `Spree::DeliveryMethodService` rows narrow/rename/mark-up services (no rows = all, method-level markup columns as default); selection + EasyPost label buy key off the selected rate's carrier/service; seeds/sample data reshaped Shopify-style (Domestic + International zones with basic methods)
- `6.0-delivery-zones.md` — Zone → DeliveryZone with postal-code-range/prefix members (country-scoped); owns the full ~183-reference Zone consumer inventory; `Spree::Zone` dropped entirely by end of 6.0 (2026-07-27 — 6.0 is the breaking-change window)
- `6.0-integrations-admin.md` — **Implemented (2026-08-06).** `Spree::Integration` as the single credential surface for all provider seams (delivery rates/tax/fulfillment/pickup points): explicit `Spree.integrations` registry, Admin API v3 CRUD + types discovery (reusing `PreferenceSchema`/`Masking` — secrets are `:password` preferences), dashboard `/settings/integrations` gallery grouped by `integration_group`. Verify-before-activate (`active: true` runs `can_connect?`, 422 on failure), ephemeral connection status. Constraints now: provider gems ship an Integration subclass (no env-var credential contracts for per-store providers); no per-provider credential UIs — pickers deep-link to the integrations page.
- `6.0-rich-text-descriptions.md` — Drop ActionText **entirely** at 6.0 (incl. CustomFields::RichText values + Order/User internal notes; gem dependency removed), store sanitized HTML in text columns, serve `field` + `field_html`, **write via `field_html`** (read/write symmetry). description_html serializer shipped 5.4; sanitizer shipped in **5.6.2** with a permissive-but-safe configurable allowlist + `sanitize_rich_text` step in the 5.5→5.6 upgrade manifest (decisions.md 2026-07-27/28), tightened to the Tiptap set at 6.0
- `6.0-inventory-operations.md` — StockTransfer lifecycle (draft → ready_to_ship → in_transit → received with partial receive), new `Spree::PurchaseOrder` + `Spree::Supplier` (renamed from Vendor — `Spree::Vendor` is the marketplace seller, see decisions.md 2026-07-14) replacing today's "external receive" hack, variant + stock-location stock history panels. Consumes the typed-movement primitives from `6.0-typed-stock-movements.md`.
- `6.0-replace-taxons-with-categories.md` — Split Taxon into Category (hierarchy) + Collection (flat/rule-based). **Shipped to 6-0-dev (PR #14302):** the Category surface (5.5–5.6) plus the 6.0 core — `spree_taxons`→`spree_categories` table rename + inheritance flip (`Spree::Category < Spree.base_class`, `Spree::Taxon` alias kept), the full `Collection` stack (model + rules + DB/Meilisearch manual sort + API), the taxon→category/collection data migration, and de-ruling Category. Pending (all 6.1): channel-aware `CollectionRules::AvailableOn` (ships interim now, rides with channels) + dropping `spree_taxon_rules`/`Taxonomy`. No brand feature in 6.0 — brands are modeled as a Category/Collection; `brand_taxon`/`brand_name` removed with `Taxonomy`.
- `6.0-delivery-method-rules.md` — `Spree::DeliveryMethodRule` STI on DeliveryMethod (design finalized 2026-07-29): ItemTotal/Weight rules first (Channel/Market/CustomerGroup later in lockstep with payment-method-rules), enforced solely in `Stock::Estimator`'s method filter so calculator- AND provider-priced methods obey eligibility; replaces the FlatRate-only bound preferences (one-release bridge + data task). **Phase 1 shipped** (rules + Estimator seam + admin nested CRUD/types discovery + dashboard Conditions card). **2026-08-06:** `ExcludedProductsRule` (products via `spree_delivery_method_rule_products` join, Saleor-style method-side exclusion) replaces the dropped `spree_products.excluded_delivery_method_ids` JSON column; rule-reference storage picks by cardinality — small reference sets stay `normalize_id_preference` arrays, catalog-scale (products) gets a join table.
- `6.0-service-workflows.md` — Two-tier services doctrine (2026-07-30). **Tier 1 `app/services/`:** plain `ServiceModule` classes, hand-written `def call(cart:, ...)`, Ruby kwargs as the contract — the permanent default; no DSL, no new `run`-pipelines, no hand-rolled sagas. **Tier 2 `app/workflows/`:** `Spree::Workflow` — named steps inside a plain `def perform(order:, ...)` (the ActiveJob::Continuable shape; bare `super` turns parameters into readers). Vocabulary: `step`/`external_step` (+ `with:`, `on_flow_failure:`), `run_hooks` + class-level `hooks`, `failure`/`halt!`; plain `ApplicationRecord.transaction`/`with_lock`/`rescue`/`publish_event`; every step instrumented as `step.spree_workflow`. Money lives in `Carts::RecalculateTotals` (single totals seam; the completed-order branch is the post-placement resum — rows re-summed, never regenerated), statuses in `Orders::UpdateStatuses` (refreshes each fulfillment's state, then rolls up); Order/CartUpdater are 6.1-removed warning shells. Shared Cart/Order surface lives in `Spree::Purchase::*` concerns; completion side effects (newsletter, account creation, risk) run in the sync `OrderPlacedSubscriber` on order.placed. Reserved for flows needing hooks, compensation/external I/O, or replay — currently `Carts::Complete`, `Carts::AddItem`, `Carts::Recalculate`, `Carts::RecalculateTotals` (+ order twins) and `Orders::Cancel` (absorbed `Order#after_cancel`; gateway settlement is an external_step). A service graduates to the workflow tier when it earns a hook, never speculatively — but hooks on flows already in the tier ship deliberately on the 6.0 boundary (2026-08-02), since hook keys are public API and moving one later is breaking. **New models get no state machine** — plain `status` string + inclusion validation, transitions through workflows; gateway I/O never in a save callback. Three hook families, contracts settled 2026-08-02: **lifecycle** (past tense, read-only), **validate** (handler calls `workflow.reject!(message)` to veto), **context** (`set_*_context`/`get_provider_data` — handler returns a hash, `run_hooks` deep-merges all handlers and returns it; last writer wins on collision). Phase 3 **shipped (2026-08-02)**: `run_hooks` returns the merged hash and `Workflow#reject!` is public API; `validate`/context/lifecycle hooks live on AddItem, Complete, Recalculate, RecalculateTotals, Cancel and Resume; `Fulfillments::Create`, `Payments::Capture`/`Refund`, `Payments::HandleWebhook` and `Carts::Merge` moved to `app/workflows/` (seams `fulfillment_create_workflow`, `payment_capture_workflow`, `payment_refund_workflow`, `payments_handle_webhook_workflow`, `cart_merge_workflow`; legacy names readable one release). **Customer registration (2026-08-05):** `Customers::Create` (seam `customer_create_workflow`, hooks `customers.create.validate`/`after_create`) is the single storefront customer-creation flow — self-registration + checkout account box (optional `order:` adopts addresses and links the order); absorbs `Orders::CreateUserAccount` (deprecated shell); admin create stays plain CRUD; token issuance stays in controllers; core sends NO welcome email — signup email is host-app code on `user.created` or the `after_create` hook. Payment workflows own the transaction boundary and guards — money movement stays in the model, called from an `external_step`. No workflows for plain CRUD. Workflow Dependencies seams use `*_workflow` keys; legacy `*_service` names stay settable/readable with warnings until 6.1 but writes are stashed, never applied (old service classes aren't workflow-contract compatible). `Carts::Complete` battery must pass unmodified. **Durability = plain Rails:** long-running background work uses `ActiveJob::Continuable` directly (reference: `Spree::Imports::ProcessJob` — CSV spine with a row-number cursor; `CreateRowsJob`/`ProcessRowsJob` deprecated shells); workflows are synchronous request-cycle flows and are NOT jobs — Workflow-level durable execution ships only if the payout run proves the need.
- `6.0-store-scoped-configuration.md` — Move nine commerce-behavior globals (`auto_capture`, `auto_capture_on_dispatch`, `allow_checkout_on_gateway_error`, `track_inventory_levels`, `stock_reservations_enabled`, `track_price_history`, `show_products_without_price`, `address_requires_phone`, `disable_sku_validation`) from `Spree::Config` to `Spree::Store` preferences. Store preference is **authoritative — no runtime fallback** (a fallback chain is what made `default_stock_reservation_ttl_minutes` silently unreachable); upgrade carries values over via `spree:store_settings:backfill_from_config`; globals are deprecated shells until 6.1. Storeless readers (`Address`, the product availability scope) use `Spree::Current.store` with a default fallback. Seven dead settings (`products_per_page`, `storefront_*_path`, …) get shells then deletion. **Constraints now:** no new `Spree::Config` reads of the movers; new behavior flags are born on Store, never global; jobs that validate addresses or query the catalog must set `Spree::Current.store`.
- `6.0-store-scoped-custom-field-definitions.md` — Add `store_id` + persisted `filter_key` to `Spree::MetafieldDefinition` (today global and computed), making uniqueness `(store_id, resource_type, filter_key)` with a DB index. Deferred from the 5.6 custom-field search/sort/filter work (schema change, not patch-safe). **Until then:** `filter_key` is a computed method — no Ransack predicates or `where`/`order` against it; definitions are global; uniqueness rests on a `CONCAT` validation with no index behind it.

Multi-version plans (some phases shipped, some pending):
- `6.0-6.1-split-adjustments.md` — Replace polymorphic Adjustment with TaxLine, Discount, Fee. **6.0 implementation fully shipped to main** (typed tables + models, `Spree::Adjusters::*` winner-only promotion adjuster, `Spree.tax_provider` seam, admin `/orders/:id/{tax_lines,discounts,fees}` API + SDK + dashboard cards, `spree:migrate_adjustments_to_typed_rows` in the upgrade manifest; legacy `Adjustment`/`AdjustmentSource` deleted). v6 developer docs shipped (`docs/v6/developer/` taxes-discounts-fees + promotions + custom-promotion). Remaining: 6.1 drops `spree_adjustments` + deprecated shells and adds `Promotion#combines_with` stacking.
- `5.4-store-api-naming-standardization.md` — Standardize API naming against industry (address fields, discounts, customer_note, label, brand/last4, etc.). 5.4 model/API aliases shipped; 6.0 column/table renames pending.
- `5.4-6.0-eu-legal-compliance.md` — GDPR (data export/anonymization, consent timestamps), Omnibus (PriceHistory, lowest-in-30-days), Consumer Rights (withdrawal period). 5.4 PriceHistory + `prior_price` shipped; GDPR endpoints + withdrawal period still pending.
- `5.4-6.0-custom-fields-rename.md` — Rename Metafields → Custom Fields. 5.4 API bridge + 5.5 `Spree::CustomField`/`CustomFieldDefinition` constant aliases shipped; 6.0 model/table rename pending.
- `5.4-6.0-product-media-system.md` — Product-level media gallery. 5.5 data model (spree_variant_media, media_type, focal_point, external_video_url) shipped; admin UIs in progress; 6.0 cleanup pending.
- `5.5-6.0-order-cancellation-and-approval.md` — First-class `OrderCancellation` + `OrderApproval` models. 5.5 models + migrations shipped; 6.0 drops denormalized columns.
- `5.5-6.0-display-on-to-boolean.md` — Collapse `display_on` tri-state to a single `storefront_visible` boolean. 5.5 bridge (`storefront_visible` accessor + Ransacker on `Spree::DisplayOn`) shipped; 6.0 schema rename pending.
- `6.0-order-routing.md` — Two-tier extension: pluggable `Spree::OrderRouting::Strategy::Base` + STI subclasses of `Spree::OrderRoutingRule`. Phase 1 (5.5) shipped: `Channel`, `OrderRoutingRule`, strategy base + Rules + Reducer + Legacy, `preferred_stock_location_id` + `channel_id` on Order. Phase 2+ (6.0) layers Catalog/Company on top via `6.0-channels-catalogs-b2b.md`.
- `6.0-channels-catalogs-b2b.md` — Channel + ProductPublication (replaces StoreProduct) + single-owner Product (`belongs_to :store`) + Publishing card (legacy admin + SPA) + `Channel#default` boolean shipped in 5.5. Channel-level gated storefront access (`storefront_access` enum + channel-owned `guest_checkout`, both with store fallback, enforced in the v3 Store API) targeted for 5.6. Catalog, Company/CompanyLocation/CompanyContact for B2B **deferred to 6.1** (the B2B release — see `docs/plans/decisions.md` 2026-06-16; filename keeps `6.0-` prefix for stable cross-refs). Multi-store catalogs (historic `Product has_many :stores`) move to the `spree_multi_store` extension.
- `5.6-6.0-single-store-promotions-payment-methods.md` — Migrate `Spree::Promotion` + `Spree::PaymentMethod` from multi-store (`has_many :stores` via `spree_promotions_stores` / `spree_payment_methods_stores` join tables) to single-owner `belongs_to :store`, mirroring the 5.5 single-owner Product migration. 5.6 (implemented): `store_id` FK + required-store presence via `Spree::SingleStoreResource`, backfill rake task (loud per-record deprecation on shared records), shared `LegacyMultiStoreSupport` deprecation bridge, deletes the `ResourceController` `store_ids=` seam, deprecates `StoreScopedResource`; multi-store sharing moves to the `spree_multi_store` extension (join tables left intact). 6.0 cleanup: enforce `null: false`, drop join tables + bridges. Paired with `6.0-channels-catalogs-b2b.md`.
- `5.6-project-layout-and-dashboard.md` — React Dashboard Developer Preview packaging + `backend/` → `api/` project layout. Implemented: `<Dashboard />` shell export from `@spree/dashboard` (source-only, relative imports only), monorepo-canonical `packages/dashboard-starter` thin host (embedded standalone into the `@spree/cli` tarball at build time via `scripts/sync-dashboard-starter.mjs` — no template repo; create-spree-app delegates to the project-local `spree add dashboard`), `spree add dashboard` + create-spree-app dashboard phase (opt-in via `--react-dashboard` while WIP — not prompted; env carries only `VITE_API_PROXY_TARGET` — never secret keys, and never `VITE_SPREE_API_URL`, which would flip the SDK to absolute cross-origin URLs and break dev on CORS), npm release job for `@spree/dashboard{,-ui,-core}` (0.x → `next` tag). Pending: layout rename + `detectApiDir` dual-layout CLI, `spree upgrade layout`; optional public template repo at 6.0 GA.
- `5.6-dashboard-typed-plugin-routes.md` — Plugin file routes compiled into the host's TanStack route tree: `spree.dashboard.routes` marker + virtual-route-config composition in `@spree/dashboard/vite`, `createDashboardRouter` + `<Dashboard router>` ownership inversion, typed cast-free links, cross-package collision pre-flight with package-named errors. Runtime route registry stays for dynamic/in-app cases (catch-all is lowest priority). Implemented; published-tarball spike passed.

Pending design work (drafts, no implementation yet):
- `6.1-order-change-substrate.md` — `Spree::OrderChange` + `Spree::OrderChangeAction`: one preview-then-apply substrate behind every post-placement mutation (admin order edits, returns, exchanges, claims, draft-order amendments), replacing four per-domain draft models with one `begin → request → confirm → cancel` lifecycle. Actions are typed `kind` + concrete FKs (never polymorphic); **preview is computed in memory and never persisted**; confirm is a workflow with the balance settlement as an `external_step`. Deliberately 6.1 — new schema + new extension API, and 6.0 already carries the Cart/Order split, typed adjustments and the returns rework. **Resolved 2026-08-10:** a change set belongs to one `Order`, never an `OrderGroup` (multi-vendor edits = N change sets, each settling against its own order); a pending change set does **not** hold stock (`add_item` takes stock at confirm — reservations are checkout-scoped and would have no expiry trigger here). Phase 3 replaces the **6.0 order edit screen** (`/orders/$orderId/edit`) — quantities as inputs, `x` marks a row removed, Save applies the batch (**reshaped 2026-08-11**, reversing the original immediate-write rule); Phase 3 adds `begin`/preview/`confirm` behind the Save/Discard it already has. 6.0 constraints: don't **persist** a draft/preview model (transient React form state is fine and is the shape the substrate wants), don't compute projected totals client-side to fake a preview, expose post-placement money math through a service returning a value object, and keep line-item mutation on the edit screen rather than the fulfillment card. Known gap: the batch save is not atomic (no bulk endpoint; Phase 3's `Confirm` fixes it in one transaction).
- `6.0-payment-method-rules.md` — `Spree::PaymentMethodRule` STI on PaymentMethod (Channel / Market / OrderTotal / CustomerGroup rules), mirroring the PromotionRule/PriceRule/OrderRoutingRule pattern. Enforced solely through `Order#collect_frontend_payment_methods` (listing + `Payments::Create` + payment sessions all flow through it); admin/backoffice bypasses; no rules = available everywhere. Dashboard-only management (nested Admin API CRUD + `/payment_method_rules/types` discovery). Supersedes the "no distribution concept" rationale in `5.6-6.0-single-store-promotions-payment-methods.md`; per-channel provider credentials (multiple Stripe accounts, multi-entity setups) explicitly deferred for grooming — see decisions.md 2026-07-23.
- `6.0-channel-delivery.md` — **Implemented in PR #14404 (2026-08-09).** Optional Channel→StockLocations allowlist (`spree_channel_stock_locations`, empty = all): constrains which fulfillment origins serve a channel's traffic, enforced origin-side (Coordinator allocation + pickup discovery intersect `Channel#serves_location?`) — never on profiles/groups (channel constraint composes from outside; Medusa-shaped transitive delivery). `preferred_stock_location_id` must be a served location. **Per-channel rates** are a separate axis: `DeliveryMethodRules::ChannelRule` (STI, beside ItemTotal/Weight/ExcludedProducts) gates which methods a channel is *offered* from origins it already reaches — origins decide whether a channel can be served, rules decide what it sees.
- `6.0-channel-markets.md` — Optional Channel→Markets allowlist (`spree_channel_markets` join, empty = all markets). Enforced in market resolution (`set_market_from_country` + channel-aware `Spree::Current.market` fallback), channel-filtered Store API `/store/markets`, and order-level `market must be served by channel` validation. Composes with `MarketRule` from the payment-method-rules plan.
- `5.6-admin-spa-csv-import.md` — Universal dashboard CSV import over the existing `Spree::Import` pipeline (implemented). Admin API v3 surface (create via direct-upload signed blob, `complete_mapping`, `retry_failed_rows`, nested failed-rows index, write-scope gating), `client.imports` SDK resource, dashboard-core `ImportButton` (per-context `<Can>` gating, upload Sheet) + full-window wizard dialog driven by an `?import=` search param, with history under `/settings/imports` (new `audit` settings-nav group). Status via API polling — explicitly no ActionCable/Turbo Streams in the SPA; legacy per-row live feed replaced by polled counters + paginated failed-rows table.
- `5.5-6.0-resource-translations-api.md` — Admin API v3 translation management + React dashboard for all `Spree.translatable_resources`. Hybrid: embedded `translations` object on resource update + generic dedicated `…/:id/translations` endpoint (one registry-driven controller), self-describing field discovery, advisory server-side staleness. Canonical `{ locale → { field → value } }` shape (consistent with metafield-translations). Cross-record bulk = CSV import/export generalized across the registry (NOT a JSON bulk endpoint — no competitor ships one). Phase 1 (5.5) API; Phase 2 (6.0) coverage read + CSV generalization + staleness + centralized SPA page; Phase 3 folds in metafields.
- `5.4-centralized-translations-admin.md` — Centralized Translations admin page under Products, overview grid + bulk CSV import/export
- `5.4-metafield-translations.md` — Translate MetafieldDefinition names + Metafield text values (ShortText, LongText, RichText) via Mobility translation tables
- `5.5-admin-api-cli.md` — `spree api` command group in `@spree/cli` (gh-api-style generic verbs + schema introspection + layered auth, CLI-first ahead of MCP servers; core patch: `SCOPES` on `spree:cli:create_api_key`, promotions scopes)

Shipped plans:
- `5.4-store-api-bridges.md` — Bridge 6.0 naming into 5.4 Store API (PR #13782)
- `5.4-spree-starter-and-create-spree-app.md` — Replace monorepo server/ with spree-starter template repo
- `5.4-option-type-enhancements.md` — `kind` (dropdown/color_swatch/buttons) on OptionType + `color_code` on OptionValue
- `5.4-search-provider.md` — Pluggable SearchProvider interface (Database + Meilisearch); PgSearch + `add_search_scope` removed (6.0 MetafieldDefinition faceting still pending)
- `5.4-disjunctive-option-faceting.md` — Per-option-type filter params with disjunctive facet counts (`FiltersAggregator` for DB, `merge_disjunctive_facets` for Meilisearch)
- `6.0-stock-reservations.md` — Time-limited stock reservations during checkout (PR #13978; Cart/Order split integration + `allocated_count` term still pending for 6.0)
- `5.5-admin-api-key-scopes.md` — granular `read_*`/`write_*` scopes on `Spree::ApiKey` for app authorization
- `5.5-admin-auth-cookie-refresh.md` — Admin SPA refresh token in httpOnly cookie, access token in memory, server-side logout
- `5.5-admin-customers-api.md` — Admin Customers + nested addresses/credit_cards/store_credits + CustomerGroups
- `5.5-admin-spa-csv-export.md` — Admin API ExportsController + admin-sdk + `useExport` + toolbar export button
- `5.5-agent-skills.md` — `spree/agent-skills` standalone repo: 25 Claude Code skills + `spree-expert` subagent + safety hooks, distributed via `npx skills add spree/agent-skills`

## Monorepo Structure

| Directory | Description |
|---|---|
| `spree/core` | Ruby gem — models, services, business logic (`spree_core`) |
| `spree/api` | Ruby gem — Store & Admin REST APIs (`spree_api`) |
| `spree/emails` | Ruby gem — transactional emails (optional). Rebuilt + modernized in 5.6. The default email stack for installations without a storefront app (e.g. mobile apps); headless storefronts may instead own consumer emails via webhooks. |
| `spree/providers/easypost` | Ruby gem (`spree_easypost`, optional) — reference `DeliveryRateProvider` + `FulfillmentProvider`: live EasyPost rates, label purchase/refund, credentials via `SpreeEasyPost::Integration`. Provider gems live under `spree/providers/` (stripe/adyen/avalara land there too); gem names stay flat. |
| `spree/dashboard` | Ruby gem (`spree_dashboard`, optional) — hosts a built React Dashboard at `/dashboard` from `Spree::Dashboard.dist_path` / `SPREE_DASHBOARD_DIST_PATH` (single-node topology). Successor slot to `spree_admin` at 6.0. |
| `packages/dashboard` | `@spree/dashboard` — React SPA admin dashboard (Spree 6.0, replaces `spree/admin`). The deployable app shell, routes, schemas, resource hooks, locales. |
| `packages/dashboard-ui` | `@spree/dashboard-ui` — design system. Shadcn primitives + headless composed components + tokens. Source-only; consumer compiles via Vite/Tailwind. **Components are headless: data comes via props, no provider/hook imports.** |
| `packages/dashboard-core` | `@spree/dashboard-core` — framework. Registries (table, nav, slot, settings-nav), providers (auth, permission, store, theme), generic infra hooks, admin SDK client singleton, `defineDashboardPlugin` facade. The extension API for plugin authors. |
| `packages/dashboard-starter` | `@spree/dashboard-starter` — thin host app consuming `<Dashboard />` from `@spree/dashboard`; canonical source of the `spree/dashboard-starter` template repo (synced on release). Doubles as the in-repo consumer test for the plugin pipeline. |
| `packages/sdk` | `@spree/sdk` — TypeScript Store API client |
| `packages/admin-sdk` | `@spree/admin-sdk` — TypeScript Admin API client (Developer Preview) |
| `packages/sdk-core` | `@spree/sdk-core` — shared HTTP/retry/error layer (private internal) |
| `packages/cli` | `@spree/cli` — Docker-based project management CLI |
| `packages/create-spree-app` | `create-spree-app` — project scaffolding |
| `server/` | Rails app cloned from `spree/spree-starter` (.gitignored, provisioned per worktree by `scripts/worktree/setup.sh`) |

## Development Server (worktrees)

Development happens in **git worktrees** — every worktree is a self-contained native dev environment, no Docker: its own gitignored `server/` clone of spree-starter (monorepo gems loaded as path gems via `SPREE_PATH`), its own database on the shared Homebrew Postgres (:5432, copied in ~2 s from the seeded `spree_worktree_template`), and stable per-branch https URLs via [portless](https://github.com/vercel-labs/portless). Worktrees are managed with [worktrunk](https://worktrunk.dev) (`wt`): creating one runs `scripts/worktree/setup.sh` automatically (see `.config/wt.toml`), removing one drops its databases. The main checkout is for integration (merges, template rebuilds), not for running servers.

```bash
wt switch -c feature-x       # create worktree + provisioned environment (~20 s)
pnpm wt:dev                  # Rails → https://feature-x.spree.localhost  (/up, /api/v3, /jobs; jobs run inside Puma via Solid Queue)
pnpm wt:dashboard            # admin UI → https://admin.feature-x.spree.localhost
pnpm wt:e2e [spec...]        # Playwright on this worktree's own port block
pnpm wt:template             # rebuild the template DB after schema-changing pulls
wt merge main                # ship + clean up (worktree, branch and databases all removed)
wt remove                    # abandon instead of shipping
```

Admin login: `spree@example.com` / `spree123`. Both dev scripts run in the foreground and stream logs; `server/log/development.log` has the Rails log if the server runs detached. Start servers only in worktrees you're actively looking at — rspec/vitest/tsc need no servers.

One-time machine setup: Homebrew `postgresql@18` running on :5432 (with a `postgres` superuser role), Ruby per `server/.ruby-version` (mise or rbenv), Node ≥ 24 with `npm i -g portless` (start the proxy once with `portless proxy start`, accepting sudo for :443), worktrunk, then `pnpm wt:template`.

| What changed | What to run (inside the worktree) |
|---|---|
| Ruby code in `spree/*` gems | Nothing — path gems, reloads on next request |
| New migration in a gem | `cd server && bin/rails spree:install:migrations db:migrate`; then `pnpm wt:template` once so future worktrees inherit it |
| Gem dependencies | `cd server && bundle install` (the gem home is shared across worktrees, so this is fast) |
| Need sample data (products + images) | `cd server && bin/rails spree:load_sample_data` — per worktree, on demand; takes minutes and hits the network |
| Rails console / database | `cd server && bin/rails console`; the DB is `spree_dev_<branch>` on `localhost:5432` |
| E2E prerequisites | Once per worktree: `cd spree/api && bundle install && bundle exec rake test_app` (then `pnpm wt:e2e`) |
| Meilisearch search provider | Optional: `brew install meilisearch`, run it, set `MEILISEARCH_URL` in `server/.env`, `bin/rails spree:search:reindex` |
| Hosted dashboard at `/dashboard` (single-node test) | `pnpm server:dashboard` to build `packages/dashboard-starter/dist`, set `SPREE_DASHBOARD_DIST_PATH=<monorepo>/packages/dashboard-starter/dist` in `server/.env` |
| Broken beyond repair | `wt remove` and recreate — or `dropdb spree_dev_<branch>`, delete `server/`, re-run `pnpm wt:setup` |

**The legacy Docker compose flow (`pnpm server:setup` / `server:dev` / `server:stop` etc.) is deprecated — never use it.** It exists only for spree-starter parity; it fights the worktree stack for ports and its teardown scripts wipe shared state.

---

## General rules

- ONLY comment complex or non-obvious methods/code, do not comment every method or class, DON'T create comments noise
- Commit message body: be precise, DON'T include implementation detail, focus on the "what" and "why", not the "how"
- If n-commits are needed for a single logical change, use `git commit --fixup` for the follow-ups and `git rebase -i --autosquash` to combine into a single commit before merging
- Documentation also needs to follow the same principles — focus on the "what" and "why", not the "how". Don't include implementation details in docs. Docs should explain the feature, its purpose, and how to use it, but not how it's implemented internally.
- NEVER commit anything to main branch, always use feature/fix/chore branches for development
- ALWAYS use plain english language when communicating with the human, NEVER use technical jargon, be precise and clear, avoid abbreviations and acronyms, and use proper grammar and punctuation. Avoid using slang or informal language. Use simple and concise sentences to convey your message effectively. Avoid using complex sentence structures or convoluted phrasing that may confuse the reader. Use active voice instead of passive voice whenever possible. Avoid using overly technical terms or industry-specific jargon that may not be familiar to the reader. Use examples or analogies to explain complex concepts in a way that is easy to understand. Avoid using vague or ambiguous language that may lead to misinterpretation. Use headings, bullet points, and numbered lists to organize information and make it easier to read. Avoid using long paragraphs or blocks of text that may overwhelm the reader. Use visuals such as diagrams, charts, or screenshots to supplement written explanations when appropriate. Avoid using visuals that are unclear or difficult to interpret.

## Backend (Ruby)

### Architecture Principles

- All code namespaced under `Spree::` module
- Follow Rails conventions and the Rails Security Guide
- RESTful routes and action names
- CanCanCan for authorization: listings use `accessible_by(current_ability, :show)`, other actions use `authorize!`
- Always use scope fetching for security (e.g. `current_store.orders` not `Spree::Order`). This applies to **every** lookup in a controller, including the incidental ones — resolving a `reason_id` or `stock_location_id` from a create param through the model constant accepts an id belonging to another store. Reading it through `current_store.<association>` turns that into a 404, which is the cheapest defence against IDOR. `accessible_by(current_ability, ...)` is not a substitute: it filters by role, not by tenant.
- Ransack for filtering/searching, Pagy for pagination
- Use services only when necessary — prefer standard Rails models and concerns
- DO NOT call `Spree::User` directly, use `Spree.user_class`; same for `Spree.admin_user_class`
- DO NOT put logic into controllers or serializers - this should live in models and services
- ALWAYS use Yard comments for classes and public methods, with `@param` and `@return` types
- DO NOT generate too much comment noise, be very strict and selective about what gets a comment — only non-obvious public methods, never private methods or internal helpers
- DO NOT use shorthand variable names, readibility by humans is the core principle

### Code Organization

All backend code lives inside `spree/` engine directories following Rails conventions:

- `app/models/spree/`, `app/controllers/spree/`, `app/services/spree/`, `app/serializers/spree/`, `app/subscribers/spree/`, `app/mailers/spree/`, `app/jobs/spree/`, `app/helpers/spree/`, `app/presenters/spree/`
- File naming matches class: `spree/product.rb` → `Spree::Product`
- Split large models into concerns, organized by topic

### Spree::Current

Per-request context available in models, controllers, jobs, and services:

- `Spree::Current.store` — current store
- `Spree::Current.currency` — current currency
- `Spree::Current.locale` — current locale

### Models

- ALWAYS Inherit from `Spree.base_class`
- New models carrying store-specific data (configuration, catalog, commerce records) ALWAYS `belongs_to :store` via `Spree::SingleStoreResource` — only genuinely global reference data (countries, states, roles) goes unscoped. Cross-store sharing is gone (`spree_multi_store` is legacy and unsupported)
- ALWAYS pass `class_name` and `dependent` on associations; use `dependent: :destroy_async` for high-fanout associations to offload deletion to a background job
- Include `Spree::Metafields` for custom fields support (see docs/plans/5.4-6.0-custom-fields-rename.md)
- Include `Spree::Metadata` for JSON metadata support
- ALWAYS Use string columns instead of enums
- NEVER use `Struct` for domain value objects — use a plain Ruby class with `ActiveModel::Model` + `ActiveModel::Attributes` (typed attributes, validations) so it behaves like an ActiveRecord object (e.g. `Spree::PickupPointOption`)
- State machines: use `state_machines-activerecord` gem, default column `status` (legacy uses `state`, see docs/plans/6.0-normalize-state-to-status.md)
- NEVER cast IDs to integer — always treat as strings (UUID support)
- Uniqueness validations: ALWAYS use `scope: spree_base_uniqueness_scope`, should be also enforced by database index
- If needed use paranoia gem for soft delete support (via `acts_as_paranoid`)
- For configuration / options always use [Model Preferences](docs/developer/customization/model-preferences.mdx)
- NEVER hardcode table names, always use `Model.table_name` in models, queries, scopes, etc.
- ALWAYS use Arel, scopes and ActiveRecord helpers to build queries, only use raw SQL if cannot use Arel

```ruby
class Spree::Product < Spree.base_class
  include Spree::Metafields
  include Spree::Metadata

  acts_as_paranoid

  has_many :variants, class_name: 'Spree::Variant', dependent: :destroy
  scope :available, -> { where(available_on: ..Time.current) }

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }
end
```

### Migrations

- Target version: existing migrations keep their `ActiveRecord::Migration[7.2]` marker; new 6.0 migrations may target `[8.1]` — the 6.0 line requires Rails 8.1 (decisions.md 2026-07-29)
- No foreign key constraints
- No default values on string/status columns (statuses are set by the creating workflow); integer, decimal and boolean columns DO carry defaults (`quantity` 1, amounts 0) so raw inserts can't produce nulls
- Every metadata-carrying table has a single `metadata` JSON column — the `public_metadata`/`private_metadata` split was consolidated in 6.0
- Always add `null: false` on required columns
- One migration per feature when possible
- Data transformations go in rake tasks, never in migrations
- Soft delete: use `paranoia` gem, add `deleted_at` column yourself
- JSON columns must work across PostgreSQL, MySQL, and SQLite. PostgreSQL supports `t.jsonb` (binary, indexable); MySQL and SQLite do not — only `t.json`. Guard with `respond_to?`:

```ruby
# JSON column — works on PostgreSQL, MySQL, SQLite
if t.respond_to?(:jsonb)
  t.jsonb :metadata
else
  t.json :metadata
end
```

```ruby
class CreateSpreeMetafields < ActiveRecord::Migration[7.2]
  def change
    create_table :spree_metafields do |t|
      t.string :key, null: false
      t.text :value, null: false
      t.string :kind, null: false
      t.string :visibility, null: false
      t.references :resource, polymorphic: true, null: false
      t.timestamps
    end

    add_index :spree_metafields, [:resource_type, :resource_id, :key, :visibility],
              name: 'index_spree_metafields_on_resource_and_key_and_visibility'
  end
end
```

### API Controllers

The Store API (customer-facing) and Admin API (back-office) are two halves of the same v3 API and should follow the same conventions. The differences are in **what data is exposed**, **who can call it**, and **which actions are enabled by default** — not in routing style, parameter shape, or response format.

#### Hierarchy

- **Base:** `Spree::Api::V3::ResourceController` — pagination (Pagy), Ransack, CanCanCan, prefixed ID lookups, HTTP caching
- **Store API:** `Spree::Api::V3::Store::ResourceController` — publishable API key auth, **read-only by default**; opt into `create`/`update`/`destroy` per resource where it makes sense (carts, customers, addresses)
- **Admin API:** `Spree::Api::V3::Admin::ResourceController` — secret API key auth (with scopes) **or** JWT auth (with CanCanCan), **full CRUD by default** (`index`, `show`, `create`, `update`, `destroy`); subclasses don't need to redeclare actions unless restricting

#### Key overridable methods

`model_class`, `serializer_class` (use `Spree.api.serializer_name`), `scope` (call `super` and chain), `find_resource`, `permitted_params`, `collection_includes`

#### Flat request/response structure

API v3 uses flat params — no nested Rails-style wrapping. **For new controllers, prefer enumerating attributes directly with `params.permit(...)`** rather than reaching into `Spree::PermittedAttributes`. Existing controllers that use the global allowlist remain valid until migrated as part of the 6.0 transition.

```ruby
# ✅ Flat params
def permitted_params
  params.permit(:name, :description, :slug)
end

# ❌ Nested params — not used in API v3
def permitted_params
  params.require(:product).permit(:name, :description, :slug)
end
```

**Read and write attribute names must match.** Whatever a serializer exposes (`label`, `status`, `customer_note`) is what the controller's `permitted_params` must accept on write — no "we expose `label` but accept `presentation`" mismatches. This is non-negotiable for v3: clients should not have to translate field names between read and write. When the underlying column has a legacy name, define a writer alias on the **model** (`def label=(value); self.presentation = value; end` — pair it with the matching reader) and permit the public name in the controller. The model owns the bridge, never the client. Example: `Spree::OptionType#label` / `label=` aliases — the serializer returns `label`, the controller permits `:label`, and the model translates to the underlying `presentation` column.

```ruby
module Spree::Api::V3::Store
  class ProductsController < ResourceController
    protected

    def model_class
      Spree::Product
    end

    def serializer_class
      Spree.api.product_serializer
    end

    def scope
      super.active(Spree::Current.currency)
    end
  end
end
```

```ruby
# Admin counterpart — gets full CRUD for free from the base class
module Spree::Api::V3::Admin
  class ProductsController < ResourceController
    protected

    def model_class
      Spree::Product
    end

    def serializer_class
      Spree.api.admin_product_serializer
    end

    # No need to declare index/show/create/update/destroy — inherited.
    # Only override scope/find_resource/permitted_params when behavior differs.
  end
end
```

### Prefixed IDs

All API v3 uses Stripe-style prefixed IDs (e.g. `prod_86Rf07xd4z`, `variant_k5nR8xLq`):

- Always return prefixed IDs in responses — never expose raw IDs
- Always accept prefixed IDs in request params
- `BaseSerializer` auto-converts the primary `id`; for associations use `object.association&.prefixed_id`
- Controllers use `find_by_prefix_id!` (automatic in base `ResourceController`)
- Event payloads also use prefixed IDs

```ruby
# ✅ Serializer
attribute :variant_id do |line_item|
  line_item.variant&.prefixed_id
end

# ❌ Exposes raw ID
attribute :variant_id
```

### Serializers (Alba)

Located in `api/app/serializers/spree/api/v3/`. Store and Admin APIs have separate serializers; **Admin always extends Store** so changes to public fields propagate automatically.

#### What goes where

The Store API is a customer-facing surface. The Admin API is a back-office surface. Two rules govern which serializer an attribute belongs to:

**Store serializer (customer-visible):**
- Public product/category/cart/order data the customer sees in the storefront
- Computed display values (`display_total`, `purchasable`, `in_stock`)
- Customer-facing pricing (`price`, `compare_at_price`, `prior_price` for EU Omnibus)
- **No timestamps** (`created_at`, `updated_at`, `deleted_at`) — these leak operational info and aren't useful to customers
- **No internal state** — never expose `cost_price`, internal status flags, soft-delete columns, audit logs, internal notes, `metadata`, or admin-only relations (vendors, fulfillment providers)

**Admin serializer (back-office):**
- Always include `created_at`, `updated_at`, and `deleted_at` (when paranoid)
- Cost price, margins, internal notes, `metadata`
- Internal status, audit fields (`approved_by_id`, `cancelled_by_id`)
- Operational relations (stock movements, fulfillment providers, internal customer tags)
- Anything an admin needs to see but a customer must not

```ruby
# Store serializer — customer-facing, no timestamps, no back-office data
module Spree::Api::V3
  class ProductSerializer < BaseSerializer
    typelize purchasable: :boolean, in_stock: :boolean, price: 'number | null'
    attributes :id, :name, :description, :slug, :price
  end
end

# Admin serializer — extends store, adds back-office attributes + timestamps
module Spree::Api::V3::Admin
  class ProductSerializer < V3::ProductSerializer
    typelize cost_price: 'number | null', metadata: 'Record<string, unknown> | null'
    attributes :status, :cost_price, :metadata, :created_at, :updated_at, :deleted_at
  end
end
```

- `typelize attr: :type` for computed/delegated attribute types
- Never use `typelize_from` — it connects to the database
- Customize via inheritance + `Spree.api.product_serializer = 'MyApp::ProductSerializer'`

### Events System

```ruby
order.publish_event('order.completed')
```

Subscribers go in `app/subscribers/spree/`:

```ruby
module Spree
  class OrderCompletedSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order
      ExternalService.notify_order_placed(order)
    end
  end
end
```

For new models, add `publishes_lifecycle_events` concern and create an event serializer.

### API Authentication

Four credential types, each with its own header and authorization model:

- **Publishable keys** (`pk_xxx`) — Store API, `X-Spree-API-Key` header. Identifies the store; permits public/guest endpoints. Safe to expose in client-side code.
- **Secret keys** (`sk_xxx`) — Admin API, `X-Spree-API-Key` header. **Server-to-server only.** Each key carries a list of [granular scopes](docs/plans/5.5-admin-api-key-scopes.md) (`read_products`, `write_orders`, etc.) that gate which endpoints it can hit. Authorization is scope-based, not CanCanCan-based.
- **JWT tokens** — user auth, `Authorization: Bearer <token>` header. Used by both Store API (logged-in customer) and Admin API (logged-in admin user). Admin JWT auth uses **CanCanCan abilities** for authorization, not scopes — this is what the admin SPA uses.
- **Guest cart tokens** — `X-Spree-Token` header. Authorizes operations on a specific guest cart.

Admin API authorization summary:
- Secret API key + scopes → for apps and integrations (audit-friendly, fine-grained)
- JWT + CanCanCan → for human admin users (role-based)

Both code paths converge at the same controllers; the controller checks permissions appropriately based on which credential authenticated the request.

### Dependencies System

Register swappable services in `Spree::Dependencies`:

```ruby
Spree::Dependencies.cart_add_item_service = 'Spree::Cart::AddItem'
```

### Security

- CanCanCan permission checks on all actions
- Use Rails [`params.permit`](https://api.rubyonrails.org/classes/ActionController/Parameters.html) to whitelist parameters in controllers
- Use `Spree.user_class` / `Spree.admin_user_class` — never reference user models directly
- Declare Ransack allowlists on **models** via `whitelisted_ransackable_attributes`, `whitelisted_ransackable_associations`, and `whitelisted_ransackable_scopes` to control which attributes, associations, and scopes are queryable from API requests

### Performance

- Use `includes`/`preload` to avoid N+1 queries (`ar_lazy_preload` gem also active)
- Use `Rails.cache` for expensive operations; use `cache_key_with_version` for custom keys
- Proper database indexing

### I18n

- Use `Spree.t` for translations
- Keep translations in `config/locales/en.yml` — no duplication across files

### Documentation

- Re-generate OpenAPI spec after API changes: `bundle exec rake rswag:specs:swaggerize`
- OpenAPI spec: `docs/api-reference/store.yaml` (generated from `spree/api/spec/integration`)
- Update developer docs in `docs/developer/` when relevant
- DO NOT edit the OpenAPI specs manually, it is generated from the integration tests. If you need to change the spec, change the integration tests instead and run swaggerize to regenerate the spec.

---

## Frontend (TypeScript)

### Workspace Setup

Managed with **pnpm** workspace + **Turbo** for task orchestration. All packages use **Tsup** for building and **Vitest** for testing.

```bash
pnpm install          # install all workspace deps
pnpm build            # build all packages (Turbo-cached)
pnpm test             # run all package tests
pnpm typecheck        # TypeScript validation across all packages
pnpm lint             # Biome lint across all packages
pnpm lint:fix         # Biome lint + auto-fix
pnpm format           # Biome format-write
```

**Linting:** All TypeScript packages use [Biome](https://biomejs.dev/) (replaces ESLint + Prettier). Root config at `biome.json`; per-package configs extend it via `"extends": ["../../biome.json"]` and set `"root": false`. CI runs `pnpm turbo lint` on every PR touching `packages/**`.

### @spree/sdk — Store API Client

TypeScript SDK for the customer-facing Store API v3.

**Structure:**
- `src/client.ts` — `createClient()` factory, `ClientConfig` interface
- `src/store-client.ts` — all REST endpoints as resource classes (`client.products.list()`, `client.carts.create()`, etc.)
- `src/types/generated/` — auto-generated TypeScript types from Alba serializers
- `src/zod/generated/` — auto-generated Zod schemas for runtime validation

**Patterns:**
- Flat resource pattern: `client.products.list()`, `client.carts.items.create()`
- Auth modes: publishable key (guest), JWT (customer)
- Automatic retry with exponential backoff
- `SpreeError` class with code, status, details
- Ransack query params transformed via `transformListParams()` in sdk-core

**Testing:** Vitest + MSW (Mock Service Worker) for HTTP mocking. Tests in `tests/`.

```bash
cd packages/sdk
pnpm build             # tsup build (CJS + ESM)
pnpm test              # vitest
pnpm generate:zod      # regenerate Zod schemas from TS types
pnpm typecheck
```

### @spree/admin-sdk — Admin API Client

Same patterns as `@spree/sdk` but for the Admin API. Supports both secret key (server-to-server) and JWT (admin SPA) authentication. Published under the `next` dist-tag during the Spree 6.0 Developer Preview.

### @spree/dashboard — Admin UI (React SPA)

The Spree 6.0 admin dashboard — a Vite-built React SPA that replaces the legacy Rails `spree/admin` engine entirely. Tech stack: Vite, TanStack Router (file-based, type-safe), TanStack Query, React Hook Form + Zod, shadcn/ui + Base UI + Tailwind, Biome, Vitest. All API calls go through `@spree/admin-sdk`. See [`packages/dashboard/README.md`](packages/dashboard/README.md) and `docs/plans/6.0-admin-spa.md` for the full architecture (auth, permissions, multi-store, extension points, the three-package split).

**Package boundary rules** (see `docs/plans/6.0-admin-spa.md` → "Package Split"):
- `@spree/dashboard-ui` — primitives + headless compounds. Components accept data via props, never import providers or hooks.
- `@spree/dashboard-core` — registries, providers, generic infra hooks, admin SDK client singleton, `defineDashboardPlugin`.
- `@spree/dashboard` — routes, resource hooks (`use-orders`, `use-products`, …), Zod schemas, locales, app shell.

The split lets plugin authors register UI via `defineDashboardPlugin` from `@spree/dashboard-core/plugin`, build new pages with `@spree/dashboard-ui` primitives, and reuse the same providers/hooks. It also lets app developers compose custom dashboards (e.g. vendor panels) from the same packages.

**Running the admin UI locally** (from a worktree — see "Development Server" above):

```bash
# 1. Boot this worktree's Spree backend (one terminal)
pnpm wt:dev             # foreground; streams logs — https://<branch>.spree.localhost

# 2. Boot the admin (separate terminal)
pnpm wt:dashboard       # https://admin.<branch>.spree.localhost (proxies /api/* to this worktree's Rails)
```

The starter is the canonical host — the same app `spree add dashboard` scaffolds — so local dev exercises the real consumer path (shell + plugin pipeline) while still hot-reloading `@spree/dashboard`/`-core`/`-ui` source through the workspace. Building the workspace deps first matters on a fresh worktree: the starter's `vite.config.ts` resolves the compiled Node-side Vite entries (`@spree/dashboard/vite`, `@spree/dashboard-core/vite`) from `dist/` — `pnpm wt:dashboard` handles this (turbo builds the dependency graph, then starts Vite on the portless-assigned port).

`VITE_API_PROXY_TARGET` sets the backend the dev proxy targets — the worktree setup writes it into `packages/dashboard-starter/.env.local` pointing at that worktree's Rails URL. Don't use `VITE_SPREE_API_URL` in dev — it flips the SDK to absolute cross-origin URLs, bypassing the proxy. Sign in with the seed admin user (`spree@example.com` / `spree123` — override at seed time with `ADMIN_EMAIL` / `ADMIN_PASSWORD`; see `spree/core/app/services/spree/seeds/admin_user.rb`).

**When implementing a new admin feature:**

1. **The Admin API is the only data source.** Never reach into Rails models or import server-rendered HTML. If a needed endpoint or attribute is missing, add it to `spree/api` first (see backend conventions above), regenerate types via the [Type Generation Pipeline](#type-generation-pipeline), then consume it from the SPA.
2. **Follow `docs/plans/6.0-admin-spa.md`** for the three extension points (table registry, navigation registry, component injection) and the shadcn copy-paste ownership model.
3. **Wrap SDK calls in custom hooks** under `src/hooks/` (e.g. `useOrders`, `useProduct`) — never call `adminClient` directly from components.

**Translations.** Every user-visible string in `@spree/dashboard` goes through i18next — page titles, headings, table column labels, button labels, empty states, toast messages, confirm dialog copy, select option labels, badges, status text, tooltips, helper text. Never hardcode English (or any language) into JSX, into table column definitions, or into dropdown option arrays. Keys live in `packages/dashboard/src/locales/en.json` (app-specific copy) or `packages/dashboard-core/src/locales/en.json` (cross-cutting: `admin.common.*`, `admin.fields.<attribute>.<facet>`). Reach for `i18n.t(...)` at module load (table definitions) and `useTranslation().t(...)` inside components. **Schemas in `src/schemas/` hold canonical values only — never label strings.** Build `{ value, label }` pairs at render time inside the component by mapping the canonical value list against translation keys. When adding a new translation key, ALWAYS add it to the all languages files in `packages/dashboard/src/locales/` and `packages/dashboard-core/src/locales/`.

**Destructive actions need a confirm — unless a sheet already gates them.** Any action that destroys or detaches data and fires **straight from a click** must go through `useConfirm()` with `variant: 'destructive'` first: row-level delete/remove buttons, and every bulk action that runs immediately. Bulk actions that open a picker sheet or dialog (`BulkAction.form`, `ResourcePickerSheet`) already require an explicit submit — that IS the confirmation, so don't stack a second dialog on top. `BulkAction` takes a `confirm` option (`{n}` interpolates the count) for the immediate case.

State the count for bulk (`{{count}}`, pluralized in every locale) and the record name for a single row. **When the write is immediate but the surrounding page is a dirty-tracked form, say so** — e.g. the products panel on a category/collection persists each add/remove/reorder on click while the rest of the page waits for Save, so its confirm copy reads "This takes effect immediately." Without that, merchants reasonably assume Save-or-Discard applies.

**Nested collection panels must paginate, never cap.** A panel listing records that belong to the parent (a category's or collection's products, and anything comparable) has to page through the nested endpoint and render `<Pagination meta={meta} onPageChange={...}>`. A bare `limit: 100` silently hides the remainder on a parent with thousands of children, and "select all" then quietly means "all 100 I happened to load". Two consequences to get right: show the parent's real total from `meta.count` rather than the loaded page length, and offset drag-reorder positions by `meta.from - 1`, since the reposition endpoints want an index across the whole set rather than within the page.

**Forms.** Raw React Hook Form with `<Field>` / `<Input>` / `<FieldError>` blocks. Drive each input explicitly with `form.register(...)` or a `<Controller>` for custom widgets so the form reads top-to-bottom. Wrap RHF's `handleSubmit` with a try/catch that calls `mapSpreeErrorsToForm` (`@/lib/form-errors`) to route 422 responses onto `form.formState.errors`: flat attribute keys become field errors with `aria-invalid` + `<FieldError>`; `:base` and nested keys land on `errors.root.message` so render a destructive banner at the top of the form.

```tsx
async function handleSubmit(values: FormValues) {
  try {
    await onSubmit(values)
  } catch (err) {
    if (!mapSpreeErrorsToForm(err, form.setError)) throw err
  }
}
```

- **Labels/placeholders/help** come from `packages/dashboard/src/locales/en.json` under `admin.fields.<resource>.<attribute>.{label,placeholder,help}` with cross-resource fallback `admin.fields.<attribute>.<facet>`. Dev mode logs missing keys to the console.
- **Client validation** lives in the Zod schema (`zodResolver`).
- **Mutation hooks built on `useResourceMutation` suppress their own toast for 422 responses** — the form already shows the inline message. Non-validation errors (network, 5xx, gateway) still toast. For a plain `useMutation` you want a fallback toast on, layer the catch: try `mapSpreeErrorsToForm` first, re-throw `SpreeError`, otherwise `toast.error(...)`.

**Form schemas** live in `packages/dashboard/src/schemas/<resource>.ts` when shared across 2+ files or non-trivial (~30+ lines, nested sub-schemas, companion constants); inline is fine for short single-file forms. The schema file owns the Zod schema, its inferred `FormValues` type, defaults, dropdown option arrays, and regex constants. **Don't add form↔API mappers to paper over field renames** — if you find yourself translating `ot.label → form.presentation`, fix the API instead (read/write symmetry, see "API Controllers" above). Mappers are only for pure frontend state (upload progress, transient UI bookkeeping). **Never embed SDK entity types (`Customer`, `Order`, `Channel`, …) inside a form-values type** — react-hook-form's `Path<T>` enumerates every nested key, and the SDK types embed the whole object graph, which overflows TypeScript's relation cache (`RangeError: Map maximum size exceeded` killing `tsc -b`). Display-only embeds use an opaque record instead (pattern: `RuleEmbedRecord` in `schemas/price-list.ts` — full SDK records still assign into it at runtime; the form type just stays shallow). To locate this class of failure, run `@typescript/native-preview` (tsgo) — it reports the offending comparison with a line number instead of crashing; tsc stays the build compiler.

**Base UI `<Select>` does not auto-render labels.** Unlike Radix, Base UI's `<Select.Value />` renders the raw selected `value` (the slug, the ISO code, the prefixed ID) instead of the matching `<SelectItem>`'s children. Two fixes:

1. **Static option labels** — pass an `items` array; Base UI resolves the trigger label automatically:
   ```tsx
   <Select items={KIND_OPTIONS} value={...} onValueChange={...}>
     <SelectTrigger><SelectValue /></SelectTrigger>
     <SelectContent>
       {KIND_OPTIONS.map((o) => <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>)}
     </SelectContent>
   </Select>
   ```
2. **Dynamic option labels** — use the children render-prop:
   ```tsx
   <SelectValue>{(value) => roles.find((r) => r.id === value)?.name ?? (value as string)}</SelectValue>
   ```

For free-text **searchable** pickers, use `<Combobox>` instead — see `components/spree/country-state-fields.tsx`.

**`acts_as_list` ⇒ drag-and-drop reorder, never a numeric position input.** When a model uses `acts_as_list`, both top-level list tables and nested collection editors must reorder via dnd-kit:

1. **Top-level resource tables**: pass `reorder={{ onReorder: (id, position) => adminClient.X.update(id, { position }) }}` to `<ResourceTable>` — it owns the `DndContext` + `SortableContext` internally, optimistic with rollback. Reference: `routes/_authenticated/$storeId/settings/payment-methods.tsx`.
2. **Nested collection editors** (e.g. `option_values[]` on an option-type sheet): wrap `useFieldArray` rows in `DndContext` + `SortableContext`, give each row a `<GripVerticalIcon>` grip with `{...attributes} {...listeners}` from `useSortable`, and on drag end call `valuesArray.move(from, to)` and rewrite each row's `position` to its new index. The position field is **not rendered**; it's a computed output. Reference: `routes/_authenticated/$storeId/products/options.tsx` (vertical), `routes/_authenticated/$storeId/products/$productId.tsx` (product media grid).

Use `verticalListSortingStrategy` for rows/lists, `rectSortingStrategy` for grids. Always pair `PointerSensor` (with `activationConstraint: { distance: 5 }` so row clicks don't hijack as drags) with `KeyboardSensor` + `sortableKeyboardCoordinates` for accessibility.

**`<StoreDatePicker>` is the only correct way to render a date/datetime field.** Never use `<Input type="date">` (native styling breaks the design system) or the bare `<DatePicker>` in `components/ui/` (skips the store timezone). `@/components/spree/store-date-picker` reads the store's IANA timezone from `<StoreProvider>` so every datetime in the SPA means the same thing for every admin. Modes:

- **Date-only** (default): emits `yyyy-MM-dd` strings (timezone-agnostic). Persist as-is — backend `date` columns accept these directly via Ransack.
- **Datetime** (`includeTime`): the user picks a wall-clock time in the store's timezone; the picker emits the corresponding UTC ISO string and reinterprets it on read.

Wire through `<Controller>` in forms; pass `value`/`onChange` directly in filter panels. **Inside a `<Sheet>`, pass `inline`** — the default Popover path hits the portal bug below.

**Base UI `<Popover>` is unreliable inside a `<Sheet>`'s portal tree.** Symptom: the trigger gets `aria-expanded="true"` and `data-popup-open=""` on click, but no `[data-slot="popover-content"]` ever appears in the DOM. Happens in deeply-nested portal trees (Sheet → SortableContext → TableRow → Popover). Fix: render the panel inline with `absolute top-full left-0 z-50` + a `document.pointerdown` click-outside listener + Escape-to-close. A portal is only needed to escape an `overflow: hidden` ancestor; for table cells and form fields, inline is fine. Reference: `components/spree/color-picker.tsx`, plus `<StoreDatePicker inline>` above.

### @spree/sdk-core — Shared HTTP Layer

Private package providing `createRequestFn()`, `SpreeError`, retry logic, and Ransack param transformation. Used internally by both SDKs.

### Type Generation Pipeline

When changing Alba serializers, run the full pipeline:

```bash
cd spree/api && bundle exec rake typelizer:generate    # 1. TS types from serializers
cd packages/sdk && pnpm generate:zod                     # 2. Zod schemas from TS types
cd spree/api && bundle exec rspec spec/integration/     # 3. Integration tests
bundle exec rake rswag:specs:swaggerize                 # 4. OpenAPI spec
cd packages/sdk && pnpm test                             # 5. SDK tests
```

- TypeScript types → `packages/sdk/src/types/generated/` (Store) and `packages/admin-sdk/src/types/generated/` (Admin)
- Zod schemas → `packages/sdk/src/zod/generated/`
- Store types: `StoreProduct`, `StoreOrder`, etc. Admin types: `AdminProduct`, `AdminOrder`, etc.

A **Lefthook pre-commit hook** (`lefthook.yml`) regenerates types and Zod schemas automatically whenever `spree/api/app/serializers/**/*.rb` files are committed, then re-stages the generated output. You don't need to run steps 1 and 2 manually if you're committing serializer changes — the hook handles it. Steps 3–5 (integration tests, OpenAPI regen, SDK tests) still need to run locally before pushing.

### Changesets & Versioning

Published packages use **Changesets** for versioning — one workspace-wide instance. Place changeset files in the root `.changeset/` directory (`pnpm changeset`), never in per-package directories. The dashboard packages (`@spree/dashboard`, `@spree/dashboard-core`, `@spree/dashboard-ui`) are a `fixed` group and always release together under one version; `@spree/admin-sdk` versions independently. Two release trains: `pnpm version:preview` cuts the Developer Preview packages while holding back `@spree/sdk` (stable, tracks Spree releases); `pnpm changeset version` includes it. `--ignore` defers changesets, it never discards them.

---

## Testing

Always run tests before committing changes.

### Backend (Ruby — RSpec)

Each engine has its own test suite:

```bash
cd spree && bundle install        # shared deps
cd core && bundle install         # engine deps
bundle exec rake test_app         # create dummy Rails app (skip if already exists)
bundle exec rspec                 # run full suite
bundle exec rspec spec/models/spree/state_spec.rb      # single file
bundle exec rspec spec/models/spree/state_spec.rb:7    # single test
```

Default DB is SQLite3. For PostgreSQL:

```bash
DB=postgres DB_USERNAME=postgres DB_PASSWORD=password DB_HOST=localhost bundle exec rake test_app
```

**Parallel runs:**

```bash
bundle exec rake parallel_setup          # create worker DBs
bundle exec parallel_rspec spec          # run in parallel
bundle exec parallel_rspec -n 4 spec     # with worker count
```

Re-run `parallel_setup` after schema changes.

**Test guidelines:**
- RSpec + Factory Bot
- Prefer `build` over `create` for speed
- Factories live in `lib/spree/testing_support/factories/`
- ALWAYS use factories in tests, never call `Model#create` directly
- ALWAYS run parallel tests if running full test suite, if there are any failures repeat the failed examples seperately and confirm they really fail before investigating
- Pragmatic — no tests for standard Rails validations, only custom ones
- Controller specs: always add `render_views`, use `stub_authorization!` for auth
- Use controller specs for testing edge cases, API integration tests are only for happy path/simple 422 failures to generate OpenAPI examples; otherwise they get too brittle and high-maintenance
- Time-based tests: use `Timecop`
- Don't over-engineer or repeat tests

### Frontend (TypeScript — Vitest)

```bash
cd packages/sdk && pnpm test       # SDK tests (uses MSW for HTTP mocking)
```

### Admin SPA E2E (Playwright)

End-to-end tests for `packages/dashboard` live in `packages/dashboard/e2e/`. The global setup boots a real Rails test server (port 3010) + Vite (port 5174) once and seeds the DB; specs then exercise the SPA through a browser against that stack. Locally Vite runs in dev mode; CI builds first and serves the bundle (`E2E_PREVIEW=1` → `vite preview`) because every test's fresh browser context re-downloads all dev-mode modules. CI also splits the suite across shard jobs (`--shard=n/m`), each with its own isolated Rails + SQLite + Vite stack — specs must stay self-contained (seed via global-setup fixtures or create your own records) and must not depend on records another spec file leaves behind.

```bash
cd packages/dashboard && pnpm test:e2e          # full suite
cd packages/dashboard && pnpm test:e2e:ui       # Playwright UI mode (debug)
```

The `login(page)` helper authenticates through the API (one POST plants the refresh cookie; the SPA's boot-time silent refresh does the rest) — only `auth.spec.ts` drives the login form itself.

**Write UI-only assertions, like Capybara.** Drive the test through user-visible actions (fill labels, click buttons, find by role) and assert on visible UI. **Do not** reach for `page.waitForResponse(/api/...)` to wait for backend completion — it leaks API shape into tests and makes refactors painful. Playwright's `await expect(...).toBeVisible()` auto-polls until the condition is met (same as Capybara's `default_max_wait_time`), which covers virtually all cases.

```ts
// ✅ Capybara-style: drive the UI, assert on the UI.
await page.getByLabel(/^label$/i).fill('Color')
await page.getByRole('button', { name: /create option type/i }).click()
await expect(page.getByRole('button', { name: 'color' })).toBeVisible({ timeout: 15_000 })

// ❌ Avoid: couples the test to API shape, brittle on refactor.
await Promise.all([
  page.waitForResponse((res) => /\/api\/v3\/admin\/option_types/.test(res.url()) && res.status() === 201),
  page.getByRole('button', { name: /create option type/i }).click(),
])
```

The narrow exceptions where API-level waits are justified:
- **No UI feedback** — a mutation kicks off background work (e.g., a webhook fire-and-forget) and there's nothing visible to assert against.
- **Optimistic UI** — success state appears in the DOM before the API confirms; a UI-only assertion can't distinguish "rendered and persisted" from "rendered but later failed."

Both are rare in the admin SPA, which renders success states only after mutations resolve.

**Conventions:**
- Use `Date.now()` suffixes on names so leftover rows from earlier specs don't collide (the suite runs serially — `fullyParallel: false, workers: 1`).
- Disambiguate duplicate button names (e.g., a "Delete" in the sheet footer + another in a confirm dialog) by scoping: `page.getByRole('dialog').getByRole('button', { name: /^delete$/i })`.
- Reference: `e2e/option-types.spec.ts`, `e2e/invitation-acceptance.spec.ts`.
