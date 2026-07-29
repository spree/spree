## 2026-07-27: One owner pattern for cart/order-scoped rows — dual concrete FKs, not polymorphic

The cart-order-split stub's "polymorphic `LineItem#owner`" is superseded. Every
cart-or-order-owned table uses the same shape: nullable `cart_id` + nullable
`order_id` with an exactly-one validation, and `#owner` as a plain method
(`order || cart`). Applies to `spree_line_items`, the typed money lines
(TaxLine/Discount/Fee), and Fulfillment/DeliveryRate.

Why: 6.0's design language is concrete FKs over polymorphic type strings
(split-adjustments removes `adjustable_type`/`source_type`,
typed-stock-movements removes `originator_type`) — reintroducing polymorphism
on the schema's highest-traffic table in the same release would be incoherent.
It's also the cheapest migration: `spree_line_items.order_id` already exists
and stays permanently; only a nullable `cart_id` is added, and every existing
`line_item.order` read keeps working for order-owned rows.

Provenance ("which cart did this order row come from") needs no second FK on
the row: `Order#cart_id` (unique — the completion idempotency key) links order
to cart, and the retained cart keeps its own rows as the frozen at-checkout
snapshot, so post-placement additions are distinguishable. Both-columns-set
was considered and rejected — order-side copies carrying `cart_id` would
collide with the cart's own rows in every `cart.line_items`-style association.

## 2026-07-23: Payment-method eligibility rules + Channel→Markets allowlist target 5.7; multi-credential grooming deferred

Merchant asks (wholesale net payment vs DTC Stripe, installments above an
order-total threshold, market-bound payment methods, channels limited to
certain markets) plus a four-platform review (OSS platform C channel-scoped
PaymentMethods + `PaymentMethodEligibilityChecker`, OSS platform A region-scoped
payment providers, OSS platform B per-channel payment apps, the hosted leader's Payment Customization Functions + the May-2026 per-market multi-entity payments product) settled three things:

1. **`5.7-payment-method-rules.md`** — `Spree::PaymentMethodRule` STI
   (Channel / Market / OrderTotal / CustomerGroup rules), mirroring the
   PromotionRule/PriceRule/OrderRoutingRule house pattern; enforced through
   the single `Order#collect_frontend_payment_methods` seam; storefront-only
   (admin/backoffice bypasses). Supersedes the "payment methods have no
   distribution concept" rationale in
   `5.6-6.0-single-store-promotions-payment-methods.md` — the single-store FK
   stands, eligibility is layered on via rules.
2. **`5.7-channel-markets.md`** — optional Channel→Markets allowlist
   (`spree_channel_markets`, empty = all markets), enforced in market
   resolution, the Store API markets reference endpoints, and order
   validation. Composes with `MarketRule` above.
3. **Deferred for grooming: multiple provider credentials / legal entities
   in one store** (two Stripe accounts split by channel or market, the hosted leader's
   multi-entity model). Candidate shapes — separate PaymentMethod records per
   channel/market (OSS platform C/OSS platform A style; needs the Admin API `types`
   "already installed" filter relaxed) vs per-channel credential mapping on
   one record (OSS platform B style) — plus the legal-entity attribution question
   (per-entity payouts, compliance, reporting). No plan yet; do not implement.

## 2026-07-21: Order routing rules get admin management in the React dashboard only

Per-channel `Spree::OrderRoutingRule` management (the Phase 2 "Admin API + SPA
settings page" slice of `6.0-order-routing.md`) ships ahead of the rest of
Phase 2: Admin API v3 CRUD nested under channels
(`/channels/:channel_id/order_routing_rules`) + top-level
`/order_routing_rules/types` discovery, `@spree/admin-sdk` resource, and a
routing-rules editor inside the dashboard's channel edit sheet (drag-to-reorder,
active toggles, schema-driven preference forms via `PreferencesForm`).

**No legacy Rails admin UI** — routing rules are managed exclusively in the
React dashboard. The legacy admin's channel form keeps only the strategy
override select it already had. New admin surfaces target the SPA; the legacy
admin is in maintenance mode for 6.0.

## 2026-07-20: Wholesale applicant company name stays in metadata until 6.1 Company accounts

The gated wholesale portal's apply form collects a company name. Considered
promoting it to a nullable `company` column on `spree_users` as a pre-6.1
stepping stone — mechanically fine (core already migrates that app-owned table:
`add_phone_to_spree_users`, `add_first_name_and_last_name_to_spree_users`), and
it would buy Ransack searchability and first-class serializer/export support.

**Rejected for now.** Free-text company on the customer becomes a second source
of truth the moment `Spree::Company` lands in 6.1, and free text doesn't dedupe
("Acme" / "Acme Ltd" / "ACME Limited"), so the backfill into real Company
records is messy and the column lingers as a deprecated shadow. Applicant
company is stored in customer `metadata` (`{ company: "…" }`) instead — already
supported end-to-end by `RegisterParams` + the Store customers controller, no
migration, no invented field.

The proper implementation is the Company → CompanyLocation → CompanyContact
tree in `6.0-channels-catalogs-b2b.md` Phase 2 (**6.1**). Note that plan's
decision 7: approval workflows, role-based permissions, purchase limits, and
invoice management are deferred to a dedicated B2B plan **after** 6.1 — so the
demo's manual "admin adds the customer to the Wholesale group" approval step is
intentional and survives past 6.1 until that plan exists.

Also decided: no company row in the legacy Rails admin customer view. Metadata
is exposed by the Admin API v3 customer serializer (React dashboard shows it);
the legacy admin renders customer metadata nowhere and stays that way.

## 2026-07-19: Database search provider is the out-of-the-box default; Meilisearch becomes opt-in

spree-starter and create-spree-app no longer provision Meilisearch. The Docker
compose files stop running the `meilisearch` service and stop hardcoding
`MEILISEARCH_URL`, so `Spree::SearchProvider::Database` — already the core
default and already the effective default on the native (no-Docker) path — is
now the default on every install path. One less always-on container (image
pull, RAM, volume) for the common case; `Spree::SearchProvider::IndexJob` /
`RemoveJob` never enqueue under the DB provider (`indexing_required?` is
false), so the default stack also stops paying per-save indexing jobs.

Opt-in stays config-only: commented service/depends_on/env/volume blocks in
both compose files + `MEILISEARCH_URL`, then `spree:search:reindex`. The
`meilisearch` gem stays in the starter Gemfile so the prebuilt
`ghcr.io/spree/spree` image retains the capability — enabling Meilisearch on
the quick-start compose must not require a custom image build. Docs continue
to recommend Meilisearch for production-scale catalogs (see
`5.4-search-provider.md`); this changes what's provisioned by default, not the
recommendation.

## 2026-07-15: Basic Stripe Connect payouts move to OSS; Enterprise repositions on money operations

spree/spree#13323 originally kept "Stripe Connect onboarding, KYC, automatic
payouts" in Enterprise. Amended by the issue author: the **basic** Stripe Connect
path ships **open-source in the monorepo**, registering
`Spree::PayoutProvider::StripeConnect` — Express-account onboarding (hosted link +
`account.updated` status webhook) and on-fulfillment `Stripe::Transfer` execution
(`source_transaction`-tied), plus mapping the vendor payout schedule onto Stripe's
native schedule. It lands alongside the Stripe core gateway being pulled into the
monorepo from the standalone `spree_stripe` repo — only the payment-sessions-API
gateway classes come over (likely into `spree/core`); the legacy v2-API/storefront
code in that repo stays behind.

Rationale: the closest OSS competitor ships baseline Stripe transfers free —
"money moves automatically" is the demo that sells — and transfers are inseparable
from basic onboarding (a `Stripe::Transfer` requires a connected account), so a
transfers-only OSS cut was never buildable.

Enterprise keeps the money **operations**: automatic refund clawbacks (prorated
transfer reversals + negative-balance netting), KYC/account-health workflows beyond
hosted onboarding, ledger⇄Stripe reconciliation, payout reports incl. DAC7,
marketplace-facilitator taxes, and the Shopify/WooCommerce vendor apps. Ledger
correctness (reversal rows) stays OSS in every mode — only pullback execution is
paid. "Core runs the happy path; Enterprise operates the unhappy paths and
compliance at scale." #13323 to be updated accordingly.
Plan: `6.0-multi-vendor-marketplace.md`.

## 2026-07-14: `Spree::Vendor` = marketplace seller; procurement source renamed `Spree::Supplier`

Two 6.0 plans introduced a `Spree::Vendor`: the marketplace seller
(`6.0-multi-vendor-marketplace.md`, prefix `ven_`) and the purchase-order
procurement source (`6.0-inventory-operations.md`, prefix `vnd_`). Same class
name, same `spree_vendors` table, different domains — a hard collision.

Resolution: **the marketplace owns the `Vendor` name.** It is locked publicly
(spree/spree#13323, the user docs' "Vendors" area, the legacy Enterprise gem's
`ven_` prefix and its production data). The inventory-operations model is renamed
**`Spree::Supplier`** (`spree_suppliers`, prefix `sup_`, `/api/v3/admin/suppliers`) —
matching the hosted leader's purchase-order vocabulary and standard ERP terminology. They
are different lifecycles: a supplier is an address-book entry the merchant buys
stock from; a vendor is an onboarded selling party with users, commission, and
payouts.

Hybrid marketplaces (operator buys wholesale from a marketplace seller and
resells first-party) can later bridge the two with an optional
`Spree::Supplier#vendor_id` link — not scoped for 6.0.

## 2026-06-16: Split 6.0 into Marketplace, defer B2B to 6.1

6.0 is themed as the **Marketplace release**, headlined by open-sourcing the
multi-vendor marketplace (per spree/spree#13323) alongside React dashboard GA and
the architecture/rename wave. B2B (Catalog + Company/CompanyLocation/CompanyContact
from `6.0-channels-catalogs-b2b.md` Phase 2) moves to **6.1**, marketed as the B2B
release. Rationale: a crowded 6.0 dilutes the launch; one sharp headline per release
earns more buzz, and the B2B Phase 2 work is plan-only (not started), so deferring
it frees capacity for the multi-vendor open-sourcing rather than parking finished code.

Multi-vendor OSS/Enterprise boundary per #13323 as of this date (**superseded in
part by 2026-07-15 above** — basic Stripe Connect execution later moved to OSS):
core ships Vendor identity, order splitting, the commission engine (with EU
commission taxation), the payout ledger (`Spree::VendorPayout` — records what's
owed, provider-agnostic), vendor dashboard, CSV import/export, and Vendors API;
Enterprise keeps Stripe Connect/KYC and the *execution* of payouts (a
`PayoutProvider::StripeConnect` strategy), payout reports, Shopify/WooCommerce
sales-channel apps, and the category mapper. New plan:
`6.0-multi-vendor-marketplace.md`. The legacy Enterprise multi-vendor module is
rebuilt as native core models on top of the 6.0 Cart/Order split.

## 2026-03-17: Rename StockItem → StockLevel
`Spree::StockItem` → `Spree::StockLevel`, `spree_stock_items` → `spree_stock_levels`.
Prefix ID: `si_` → `sl_`.

Every other platform uses "level" for this concept — the hosted market leader (`InventoryLevel`),
OSS platform A (`InventoryLevel`), OSS platform C (`StockLevel`), OSS platform B (`Stock`). "Item" sounds
like a physical object; "level" correctly describes "the quantity of a variant at
a location."

Part of the 6.0 model rename wave. Includes renaming the FK columns
(`stock_item_id` → `stock_level_id`) on StockMovement, StockReservation, and
any other referencing tables.

## 2026-03-16: Rename user_id → customer_id on customer-facing models
As part of the User → Customer rename (6.0-platform-auth.md), rename `user_id`
foreign key columns to `customer_id` on all models where the FK references a
storefront customer (not an admin user).

**Rename to `customer_id`** (11 models — FK references Spree.customer_class):
- `spree_orders.user_id` → `customer_id`
- `spree_addresses.user_id` → `customer_id`
- `spree_credit_cards.user_id` → `customer_id`
- `spree_store_credits.user_id` → `customer_id`
- `spree_wishlists.user_id` → `customer_id`
- `spree_gift_cards.user_id` → `customer_id`
- `spree_gateway_customers.user_id` → `customer_id`
- `spree_payment_sources.user_id` → `customer_id`
- `spree_newsletter_subscribers.user_id` → `customer_id`
- `spree_promotion_rule_users.user_id` → `customer_id`
- `spree_customer_group_users.user_id` → `customer_id`

**Keep as `user_id`** (5 models — FK references Spree.admin_user_class or is polymorphic):
- `spree_imports.user_id` — admin who ran the import
- `spree_exports.user_id` — admin who ran the export
- `spree_reports.user_id` — admin who generated the report
- `spree_state_changes.user_id` — admin who triggered the change
- `spree_user_identities.user_id` — polymorphic (Customer or AdminUser)

Single migration renames all 11 columns. Model associations updated:
`belongs_to :user` → `belongs_to :customer` with `class_name: Spree.customer_class`.

## 2026-03-16: PaymentMethod and DeliveryMethod become SingleStoreResource
Both PaymentMethod and DeliveryMethod (renamed from ShippingMethod) switch to
`SingleStoreResource` with direct `belongs_to :store`.

In practice, different stores have different currencies, zones, and provider
accounts — sharing the same payment/delivery config across stores is rare.
If a merchant wants the same config on two stores, they create two records.

**Corrected 2026-07-27:** the original entry claimed both models migrate away
from multi-store join tables (`StorePaymentMethod`, `StoreShippingMethod`).
That was only half true — `spree_store_shipping_methods` / a
`StoreShippingMethod` model **never existed**; ShippingMethod has always been
globally scoped (no store association of any kind). The PaymentMethod half was
real and shipped in 5.6 (`5.6-6.0-single-store-promotions-payment-methods.md`).
For ShippingMethod/DeliveryMethod, `store_id` is therefore a **greenfield
addition with a derived backfill** (no join table to read from), owned by
`6.0-delivery-rate-provider.md` Phase 1 — the provider needs the store to
resolve `Spree::Integration` credentials. Backfill: `Store.default` for
single-store installs; zone-overlap heuristic + loud logging for multi-store.
Note this is a behavior change for multi-store installs (globally-visible
methods become single-store), not a mechanical migration.

## 2026-03-16: Fix promotion rule/action STI namespacing
**REVERSED 2026-07-29 (Damian, during Wave 6 of the core rewrite):** the rename
shipped briefly on `feature/6-0-core-rewrite` and was rolled back — class-name
churn wasn't required by any 6.0 feature, and it forced an STI `type`-column
data migration plus extension breakage for a purely cosmetic consistency win.
Promotion rules/actions stay `Spree::Promotion::Rules::*` /
`Spree::Promotion::Actions::*` (incl. `CreateItemAdjustments`, which now writes
typed `Spree::Discount` rows under its legacy name). The STI-namespace
convention below still applies to NEW hierarchies; existing promotion classes
are grandfathered.

Original decision:
Rename `Spree::Promotion::Rules::*` → `Spree::PromotionRules::*` and
`Spree::Promotion::Actions::*` → `Spree::PromotionActions::*`.

The convention for STI subtypes is `Spree::{BaseClass}s::{Subtype}` — pluralized
base class as the namespace. Every other hierarchy follows this already:

- `Spree::PriceRules::VolumeRule`
- `Spree::Metafields::ShortText`
- `Spree::CollectionRules::Tag` (from categories plan)
- `Spree::ReimbursementType::Credit`

Promotion was the only one nesting under the parent model (`Spree::Promotion::Rules`)
instead of the base class (`Spree::PromotionRules`).

Changes:
- Move files from `app/models/spree/promotion/rules/` → `app/models/spree/promotion_rules/`
- Move files from `app/models/spree/promotion/actions/` → `app/models/spree/promotion_actions/`
- Data migration: update `type` column in `spree_promotion_rules` and `spree_promotion_actions`
  (e.g., `Spree::Promotion::Rules::Product` → `Spree::PromotionRules::Product`)
- Deprecation aliases for one release

## 2026-03-16: Normalize state → status across all models
Settle on `status` as the standard column name for state machines. Newer models
(Product, PriceList, PaymentSession, Import, Invitation) already use `status`.

Order.state and Adjustment.state are removed entirely by other 6.0 plans
(cart-order-split, split-adjustments). Five remaining models need a column
rename from `state` → `status` in 6.0:

- **Payment** — `state` → `status`
- **Shipment** — `state` → `status`
- **InventoryUnit** — `state` → `status`
- **ReturnAuthorization** — `state` → `status`
- **GiftCard** — `state` → `status`

Single migration renaming all five columns. State machine declarations updated
to `state_machine :status, initial: ...`. Deprecation aliases
(`alias_attribute :state, :status`) for one release.

Models already correct (no change): Product, PriceList, PaymentSession,
PaymentSetupSession, Import, ImportRow, Invitation, ReturnItem
(`reception_status`/`acceptance_status`), Reimbursement (`reimbursement_status`).

## 2026-03-28: Simplify metafield visibility — display_on → storefront_visible boolean (6.0)
Replace three-way `display_on` (both/front_end/back_end) with `storefront_visible`
boolean (default: true) on CustomFieldDefinition. `front_end`-only was already
excluded from `MetafieldDefinition::DISPLAY` and never made sense.

This makes the two-system boundary razor-sharp:
- Custom Fields (storefront_visible: true) = public structured data
- Custom Fields (storefront_visible: false) = admin-only structured data
- Metadata = private developer-owned data (never exposed)

Matches OSS platform C (`public: boolean`) and OSS platform B (`visibleInStorefront: boolean`).
Ships with the 6.0 model rename wave. See `5.4-6.0-custom-fields-rename.md`.

## 2026-03-16: Consolidate metadata — drop public_metadata, keep metadata JSON column
Drop `public_metadata` column (never exposed in Store API, unused). Rename
`private_metadata` → `metadata` in the database. Simplify the `Spree::Metadata`
concern to a single `metadata` JSON column with no alias indirection.

**Metadata** (JSON column) is a permanent, first-class system — the schemaless
developer escape hatch for integration IDs, sync state, ad-hoc flags. No
definition required, one-step API:
`PATCH /product { metadata: { erp_id: "123" } }`. Never exposed in Store API
(Stripe convention: write-only). Metadata is here to stay.

**Metafields** (→ Custom Fields in 6.0, see `5.4-6.0-custom-fields-rename.md`)
stay as merchant-defined structured data — typed values (short_text, number,
boolean, json, rich_text, long_text), require a `MetafieldDefinition`, have
`storefront_visible` boolean, searchable, CSV importable. With the
ProductType plan (6.0-product-types.md), metafields become schema-enforced
custom attributes driven by ProductType.

Two systems, two purposes, no overlap. No consolidation into one.
Metadata for machines, metafields/custom fields for humans.

## 2026-03-10: Product descriptions stay as plain column
Considered Action Text. Rejected for API-first performance —
serializing rich text adds overhead for every product response.
Also in the new Admin UI we will use TipTap for rich text editing.

## 2026-07-27: Delivery rate provider wraps the Estimator — shipping calculators stay

Reverses the original `6.0-delivery-rate-provider.md` key decision to delete
`ShippingCalculator` + `Calculator::Shipping::*` in favor of a `pricing_type`
enum. The enum cannot reach parity (FlexiRate/PriceSack inexpressible, FlatRate
suppression thresholds and DigitalDelivery's `available?` predicate lost) and
breaks every merchant calculator subclass with no migration path.

Instead the provider is dispatched at the single point where `Stock::Estimator`
calls `calculator.compute(package)`; the Estimator keeps method filtering, VAT
gross-up, tax resolution, and default selection. `Internal` delegates to the
calculator — zero behavior change is the acceptance criterion. All three
Estimator entry points (Shipment#refresh_rates, OrderRouting::Strategy::Rules,
Cart::EstimateShippingRates) get provider support with no per-site changes.
Accepted asymmetry: the tax provider still removes its calculators — tax
calculators were pure math with no merchant extension surface; shipping
calculators are a documented extension point.

## 2026-07-27: Zone → DeliveryZone ships in 6.0, owned by a dedicated plan

A review found the old "drop Spree::Zone entirely" wording in the tax and
delivery-rate plans had no owner for ~183 non-spec references
(`Spree::Current.zone` / `default_tax_zone`, `Market#tax_zone`,
`Order#tax_zone`, `VatPriceCalculation`, `Pricing::Context`, permission sets,
admin Zone CRUD, and the `Zone.global` factory monkey-patch every
`:shipping_method` factory depends on). Briefly scoped back the same day, then
**reinstated for 6.0 by user decision — 6.0 is the one breaking-change window;
big re-architecture does not wait for 6.1.**

Final shape: tax decouples via `6.0-tax-provider.md` Phase 5 (TaxRate direct
country/state FKs, tax readers rewritten onto `TaxRate.for_address` /
`Spree::Current.tax_country`); everything else is owned by the new
`6.0-delivery-zones.md` — `DeliveryZone` + typed members with country-scoped
postal-code ranges/prefixes, admin CRUD swap, factories rework
(worldwide-by-default methods, `Zone.global` retired), and the final
`spree_zones`/`spree_zone_members` drop at end of 6.0.

## 2026-07-27: Promotion stacking targets 6.1; 6.0 ships winner-only but stacking-ready

Stacking is among the most-requested features. Initially slated for 6.0 (the
discount engine is being rewritten there anyway), retargeted to 6.1 the same
day: stacking is **purely additive** — no schema change, no breaking window
needed — and 6.0 is already the heaviest release in Spree's history. Deferring
costs nothing structurally because the expensive prerequisites ship in 6.0
regardless (`6.0-split-adjustments.md`): typed Discount tables that permit
multiple rows per adjustable, per-adjustable clamping, and
prorate-over-the-remaining-discounted-base (needed for order-level
distribution either way), with winner-only selection isolated in a single
adjuster method.

6.1 adds: hosted-leader-style `Promotion#combines_with` flags (per class —
item/order/shipping; combining candidates all apply clamped, non-combining
compete winner-takes-all, **default off** so migrated promotions keep today's
behavior), dashboard UI, API fields. Industry: the hosted market leader combinesWith
(merchant-controlled), OSS platform A stacks all valid with caps, OSS platform C stacks
priority-ordered, OSS platform B winner-only — merchant control is the differentiated
middle.

## 2026-07-28: Customer/AdminUser models ship in the gem — no host-app model, no auth generators

Review of `6.0-platform-auth.md` surfaced an unstated inversion: today's default
production setup is a host-app-owned Devise `Spree::User` (scaffolded by the
`spree/authentication/devise` generator), while the plan's gem-shipped
`Spree::Customer`/`Spree::AdminUser` were only implicit. Made explicit:
**default models live in `spree_core` like any other Spree model; the host app
owns no auth code by default; both authentication generator directories
(`devise/` AND `custom/`) are deleted.** The only historic reason for an
app-local user model was Devise's `devise_for`/`devise :...` requirement —
dropping Devise removes it.

Rationale: auth is the worst place for generated-then-orphaned code (lockout,
rate limiting, future MFA never reach a scaffolded model without hand-merges);
matches the 6.0 strategy of customization via configuration over Rails code in
the host app. Custom user classes stay fully supported via
`Spree.customer_class` + a single `include Spree::CustomerMethods` (which
absorbs `UserAddress` + `UserPaymentSource`) — a documented recipe, not a
generator.

Migration bonus: Devise's `encrypted_password` is a plain bcrypt digest — the
same format `has_secure_password` reads — so the rake task migrating
spree-starter installs onto `spree_customers` copies it to `password_digest`
and **no customer resets their password** (task aborts loudly if
`Devise.pepper` is set).

## 2026-07-28: Core-rewrite implementation decisions (cart/order split + fulfillment + split adjustments)

Interactive review settled everything blocking implementation start; task
sequencing lives in `docs/plans/6.0-core-rewrite-tasks.md` (7 waves, data
rake tasks last).

1. **ProductType prerequisite is the minimal Phase 1 slice** — rename +
   store ownership + `fulfillment_types` + `Product#product_type_id`. The
   rest of `6.0-product-types.md` (custom-field-definition join, live
   template propagation, its API/dashboard) ships as its own effort.
2. **`spree_admin` is dropped from the spree-starter Gemfile on the 6.0
   line.** The legacy admin's adjustments/checkout screens hard-break when
   `Spree::Adjustment` and the Order state machine are removed; rather than
   limp on aliases, the dev server stops loading the gem — the React
   dashboard is the only admin. The gem stays in the monorepo untouched
   (it's already out of the CI matrix) until its 6.0 deletion; one-release
   constant aliases (`Spree::Shipment = Spree::Fulfillment`, …) still ship
   for extensions and the emails gem.
3. **`checkout_flow`/`insert_checkout_step` are hard-removed in 6.0** — no
   translation shim (machine transitions have no `Checkout::Registry`
   equivalent); migration guide instead.
4. **`DeliveryRate` carries no owner columns** — it derives `owner` through
   its fulfillment. The dual-FK pattern covers LineItem, the typed money
   lines, and Fulfillment; rates were never directly order-linked.
5. **Cart reaper defaults: guest 30d, customer 90d, empty carts 48h**
   (config preferences; carts with authorized/pending payment sessions are
   never reaped, unconditionally).
6. **`shipment.*` webhooks dual-emit for exactly one release**, dropped in 6.1.
7. **`ready_for_pickup` is a first-class Store API status** (not mapped
   onto `ready`); the order-level rollup still reports `ready`.
8. **`partially_canceled` becomes a derived predicate** over child
   cancellations, not a stored status value.

## 2026-07-29: Delivery methods stay regional; a reference multi-carrier rate provider ships in the monorepo

Question raised during 6.0 review: does one carrier method (e.g. UPS) need
per-market rates/calculators, or is "UPS (Europe)" + "UPS (North America)" as
separate `DeliveryMethod` rows a modeling smell?

Competitor survey says the split IS the industry shape — every platform
regionalizes the sellable method and shares only the carrier integration:

- **Shopify**: rates live inside Shipping Zones (per profile); a zone rate is
  a manual definition or a "participant" of a globally-registered
  CarrierService. No cross-zone method entity exists.
- **Medusa v2**: a Shipping Option belongs to exactly one Service Zone plus a
  fulfillment provider module; flat prices come from the pricing module
  (per currency/region), `calculated` delegates to the provider.
- **Saleor**: Shipping Methods live inside Shipping Zones with per-channel
  price listings; external carriers are Shipping Apps returning dynamic
  methods per checkout.
- **Vendure**: ShippingMethod is standalone (eligibility checker + calculator
  strategies) but channel-scoped — idiomatically still one method per region.

**Decision 1 — no cross-market method entity.** `DeliveryMethod` +
`DeliveryZone` already matches the consensus: method rows are cheap and
regional; carrier logic is shared one level down. Built-in calculators carry a
single `preferred_currency`, so multi-currency stores need per-market methods
regardless. Nothing to build.

**Decision 2 — the monorepo ships one reference `DeliveryRateProvider`**
backed by a multi-carrier aggregator (Shippo or EasyPost — pick pending API/
pricing review), mirroring the Stripe reference-gateway decision (2026-07-15).
One integration returns live UPS/FedEx/DHL/USPS rates, which dissolves the
per-carrier-per-market method sprawl for the majority of installs: one
"Carrier shipping" method per market, the provider returns whatever serves the
address. It also makes the reference implementation the first real consumer of
the `6.0-delivery-rate-provider.md` interface — validating the seam the way
payment sessions were validated by Stripe. Built-in calculators remain the
manual-rate path for the minority (2026-07-27 reversal unchanged).

## 2026-07-29: Geo modeling — Markets, DeliveryZones and StockLocations stay disjoint

Two follow-up questions from the same 6.0 review: should Markets link to
DeliveryZones, and should StockLocations link to DeliveryZones? Competitor
survey on both:

**Markets ↔ delivery zones.** Shopify (Markets vs profile shipping zones) and
Medusa (Regions vs service zones) keep them fully disjoint — independent
country lists, merchant coordinates, and Shopify's "market country with no
shipping coverage" dead-end is a known sore point of that camp. Saleor links
shipping zones to *channels* (m:n + per-channel price listings); Vendure
reuses one country-granular Zone entity as channel defaults for tax and
shipping — the unified model, bought at the cost of country-only granularity.

**Decision: stay disjoint.** Two structural reasons resist merging across
every platform surveyed: granularity (markets are country-level commercial
units; delivery coverage legitimately goes sub-country — states, postal
prefixes/ranges, remote-island carve-outs) and cardinality (one EU market
maps naturally onto several delivery zones — standard / remote / oversized).
Spree already carries a stronger coordination guardrail than the disjoint
camp: `MarketCountry#country_covered_by_shipping_zone` refuses market
countries the store cannot deliver to. The channel axis heads the Saleor
direction separately via `5.7-channel-markets.md`. If more convenience is
ever wanted, it is a dashboard affordance ("create delivery zone from this
market's countries"), never a schema link.

**Stock locations ↔ delivery zones.** Here the industry splits 3–1 the other
way: Shopify's delivery profiles nest location groups that each own their
zones+rates; Medusa roots the whole hierarchy at the stock location
(StockLocation → FulfillmentSet → ServiceZone → ShippingOption); Saleor links
warehouses ↔ shipping zones m:n and allocates stock through that link. Only
Vendure leaves origin/coverage coordination to code (allocation strategies).

**Decision: no StockLocation↔DeliveryZone schema link — compose it at the
method level.** Spree expresses per-origin coverage as
DeliveryMethod↔StockLocation (the `spree_delivery_method_stock_locations`
join shipped in the 6.0 rename migration, currently dormant/unwired) times
DeliveryMethod↔DeliveryZone — "UPS EU ships from the Poland warehouse" is a
method restricted to that location with EU zones. That is Shopify's
location-group→zones expressiveness without a third geo entity. Wiring the
dormant join (association + Estimator/Coordinator filtering + admin API
exposure) is follow-up work on `6.0-fulfillment-and-delivery.md`, which
already uses the table for pickup locations. The Medusa/Saleor-style
allocation question — *choosing* the warehouse by destination — is the order
routing seam (`6.0-order-routing.md` strategies), not geo schema.

## 2026-07-29: Delivery-method eligibility moves out of calculators into DeliveryMethodRule

Dashboard review surfaced min/max item-total and weight bounds rendering
inside the rate-calculator preference form. They are eligibility, not
pricing — and structurally worse than they look: the four bounds exist only
on `Calculator::Shipping::FlatRate` (no other calculator has them), are
enforced by `compute_package` returning nil rather than the
`available?(package)` hook the Estimator consults, and would be silently
LOST on provider-priced methods once `6.0-delivery-rate-provider.md` lands
(the provider bypasses the calculator that carries them).

Competitors uniformly separate the concerns: Shopify puts weight/price
conditions on the zone rate, Saleor uses method columns (+ per-channel price
bounds), Medusa v2 attaches typed ShippingOptionRule records, Vendure gives
ShippingMethod an eligibility-checker strategy parallel to its calculator.

**Decision:** `Spree::DeliveryMethodRule` STI on DeliveryMethod — the fifth
instance of the house rule pattern and the symmetric sibling of
`5.7-payment-method-rules.md` (ItemTotal + Weight first; Channel/Market/
CustomerGroup later, in lockstep with the payment set). One enforcement
seam: the Estimator's method filter, so calculator- and provider-priced
methods obey the same eligibility; no admin-bypass concept (the Estimator is
the only rate source, and these are logistics constraints). FlatRate's
bound preferences become a one-release deprecation bridge with a data task.
Plan: `6.0-delivery-method-rules.md` — targeted 6.0 directly; per the same
review, the pending 5.7 plans are expected to retarget 6.0 (skipping a 5.7
release for a faster 6.0 launch). Open questions resolved interactively the
same day: WeightRule uses the store's implicit unit (raw-number comparison,
legacy parity); rules are method-scoped only (no zone context — per-region
bounds are separate methods); Phase 1 ships with the 6.0 core-rewrite
finishing work, Channel/Market/CustomerGroup later with payment rules.


## 2026-07-29 — Admin discount application follows the Saleor shape

How should an admin apply a discount to an order in the dashboard? Competitor
survey: Shopify draft orders take only **manual** discounts (order- or
line-level custom amount/percent with a reason) — codes are a checkout
concept the buyer redeems; Medusa admin drafts accept **promotion codes**
directly; Saleor drafts take **both** a voucher code and a manual order
discount stored as its own discount object.

**Decision:** the Saleor shape, split by lifecycle. Draft orders accept
discount codes post-creation via `POST /admin/orders/:id/discount_codes`
(same `PromotionHandler::Coupon` path and pending semantics as the
storefront cart endpoint — a real-but-not-yet-eligible code is stored and
activates on recalculation); completed orders refuse codes (recalculation
is frozen) and take **manual typed Discount rows** through the existing
`/admin/orders/:id/discounts` CRUD (`Orders::AddManualDiscount`,
largest-remainder distribution, `resum_typed_totals!`). The dashboard's
promotion picker is sugar over the code path — picking a coupon promotion
fills in its code; it is not a separate application mechanism. The coupon
handler now always reports ineligibility with the retryable status code so
endpoints can tell a not-yet-qualifying code from an invalid one.


## 2026-07-29 — `order.placed` replaces `order.completed`; carts get their own events

Competitor survey (Shopify, BigCommerce, Medusa v2, Saleor, Vendure): every
platform with a separate cart entity namespaces its events (`carts/*`,
`cart.*`, `CHECKOUT_*`), and "order created" then means *placed* only where
drafts live in their own namespace (`draft_orders/*`, `DRAFT_ORDER_*`).
Medusa — the same single-Order-model shape as ours — uses an explicit
`order.placed`, and reserves `order.completed` for "fulfillment finished",
a direct collision with our historical name.

**Decisions:** carts publish `cart.created/updated/deleted` (5.x
abandonment-signal parity). The placement event is renamed
`order.completed` → **`order.placed`** — newcomers are the primary
audience and the old name misleads anyone arriving from Medusa. Per the
one-release bridge convention, 6.0 dual-emits: `order.completed` still
fires with an identical payload and `deprecated_alias_of: 'order.placed'`
in the event metadata (wildcard subscribers dedupe on it); the alias is
dropped in 6.1. The dashboard event picker offers only `order.placed`. `order.created` keeps meaning "order row exists" (admin drafts
included). Admin confirmation resends publish the targeted
`order.resend_confirmation_email` instead of re-blasting the placement
event. Order payloads carry `cart_id` (BigCommerce `store/cart/converted`
parity) so abandonment flows can cancel on conversion. Server-side
abandonment detection (BigCommerce `store/cart/abandoned`) explicitly
skipped. No separate draft-order entity and no `is_draft` boolean —
`status = 'draft'` already encodes it (`cart_id` does NOT: the completion
pipeline's draft copy has a cart_id while briefly draft; admin drafts
have none).


## 2026-07-29 — Spree 6.0 requires Rails 8.1 (7.2 support dropped)

The core gemspec already pins `rails >= 8.1, < 8.2` and the deprecation
bridges lean on Rails 8.1's `deprecated:` association option across every
6.0 rename twin — supporting 7.2 would mean hand-rolled warn-wrappers for
all of them on a platform whose security support ends 2026-08-09, before
6.0 GA. Rails 8.1 (Oct 2025, supported to Oct 2027) also unlocks
ActiveJob Continuations for resumable long-running jobs (upgrade data
migrations, imports, bulk operations — the durable-steps half of a
Medusa-style workflow story; compensation logic stays ours, e.g.
`Carts::Complete`). Existing stores upgrade Rails to 8.1 on the 5.6 line
first, then take 6.0 — 5.6 remains the bridge release. CI: the MySQL
lanes were the designated old-Rails coverage (`RAILS_VERSION: 7.2.0`) and
could no longer bundle; they now run 8.1 like the rest — MySQL itself
stays fully supported.
