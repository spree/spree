# Spree Commerce — Development Rules

## Plans & Architecture Decisions

All feature plans live in `docs/plans/` using the template at `docs/plans/_template.md`. Never create plans elsewhere.

When proposing significant architectural changes:

1. Check existing plans in `docs/plans/` for conflicts
2. Create or update a plan using the template before implementing
3. Pay special attention to "Constraints on Current Work" sections — these apply even when you're not implementing that plan directly

Use `/project:create-plan` and `/project:update-plan` for plan management, and `/project:implement-plan <plan>` to deliver a plan end to end (open questions → implementation → reviews → running QA environment → pull request).

Active plans (6.0 target, work pending):

- `6.0-b2b-storefront-purchasing.md` — Storefront company self-service (account section: members, invitations, address book, company orders; the invitation acceptance page the mailer already links) + company-aware checkout (buying-for picker on cart **and** checkout, company address book replacing the personal one at the address step). **Implemented, in review 2026-08-27** (spree/spree#14498 + spree/storefront#214). **No polymorphic owner on Cart/Order** — a purchase keeps two buyer-side parties (`customer_id` + `company_id`), the industry dual axis; OSS ships plain machinery, the polished buyer portal is Enterprise. Backend grew past the planned one-guard widening: `Spree::HasAddressBook` lets an owner declare where its default slots live (a customer's `bill_address_id` vs a company's `default_bill_address_id`) so `Addresses::Create`/`Update` work for any owner — they silently dropped a company's default flag before; default flags are three-state (claim / give up / say nothing) and released by conditional UPDATE, never read-then-write; `Company#address_book` is the inherited reading list, and reads inherit while writes stay with the owning node. **Constraints now:** never branch on an address owner's class — ask the owner (`has_address_book`); a new owner declares its slots or its defaults silently no-op; nothing storefront-side may branch on a member's "role" (OSS has none — gate on standing).
- `6.0-catalog-agreement-rework.md` — Implementation of the one-question-per-entity catalog consequences (design finalized 2026-08-30; extracted from the `6.0-b2b-companies-and-catalogs.md` amendment block so its Implemented status stops hiding unbuilt work; **sequence Wave 1 — everything catalog-shaped builds on it**; **fully implemented** — phases 1–3 2026-08-30 (schema inversion, resolver leak fix, rule supersession), phase 4 2026-08-31: inline `price_list` payload, agreement editor, products-with-prices view (`?expand=catalog_price` on the catalog's nested products listing, resolved by `Spree::Catalogs::ResolvePrices` into `explicit`/`automatic`/`base` and rendered as columns on the assortment rows), a create wizard writing once on Finish (Details → Audience → Products → Pricing → Review, on the shared `Wizard`/`WizardProgress` shell in dashboard-ui), removal warnings; the transitional `Catalog#price_list_id` accessors removed — the inline payload is the only binding; **catalogs are born inactive** and go live through `Spree::Catalogs::Activate`/`Deactivate` (hooks `after_activate`/`after_deactivate` for cache sweeps and company notifications; activation refused for a catalog with no assignments unless it is a channel's default)): the binding inversion (`spree_price_lists.catalog_id` replaces `spree_catalogs.price_list_id`; catalogs migration rewritten in place — unreleased edge; generic rule matching skips owned lists by FK in `PriceList.for_context`, closing the deactivated-catalog leak in `bound_price_list_ids`, which is deleted along with its `Spree::Current` memoization; the catalog↔list binding is applied in an `after_save`, never on assignment — a rejected save must not silently release a list store-wide); `PriceRules::CustomerGroupRule`/`UserRule` **grandfathered like `ChannelRule`** (revised 2026-08-30: kept working indefinitely, `superseded?` hides them from the rule picker — NO deprecation warning, NO removal date, NO data task; migrating who-gets-which-price automatically is a silent-price-change risk merchants gain nothing from). **Constraints now:** no new reads of `spree_catalogs.price_list_id` or `bound_price_list_ids` (the `Catalog#price_list_id` accessors are gone — bind through `price_list`, deferred into the save); no new features on the grandfathered price rules (audience targeting is catalog assignment, channel pricing is the default catalog); catalog-page features (terms, pricing card) mount on the agreement editor, never parallel surfaces; a catalog's resolved price is read through `Spree::Catalogs::ResolvePrices` or its `catalog_price` expansion — never re-derived client-side, since an adjusted amount is computed on read and never stored (that reading answers "what will this agreement charge", so it ignores the catalog's `active` flag — what a buyer actually pays is `PricingProvider::Internal`'s question); going live is never a form field — activation is its own act through the workflows, so a plain Save cannot change whether an agreement applies.
- `6.0-b2b-wholesale-shipping.md` — Wholesale/freight shipping (design finalized 2026-08-30, nothing built): **`Spree::PackageType`** — store-scoped packaging vocabulary (`box|envelope|carton|pallet|container`, one default per store Channel-style) absorbing the four `default_package_*` store preferences (one-release bridges; deliberately NOT `Spree::Package` — `Stock::Package` is the in-memory packer); variant packing chain `carton_package_type_id` + `units_per_carton` + `carton_weight` + `cartons_per_pallet` (geometry on the shared carton row, packing facts on the variant; Unit → Carton → Pallet → CBM/weight); unit-aware `Spree::FreightSummary` (units/cartons/pallets/CBM/gross weight, `complete?` flag) built on the currently-unused `Stock::Package#volume` chain via a new `Spree::Measurement` conversion helper; shipment tiers = `DeliveryMethodRules::VolumeRule` (CBM min/max) + `CompanyRule` (`company_presence`) — **no new delivery profile kind** (the same product ships parcel retail and carton wholesale, and a product has one profile); **unpriced rates are first-class** (`unpriced` on Estimate + `spree_delivery_rates`, estimator skips markup, UIs render "quoted after review" — never a $0 rate that displays as Free) returned by `DeliveryRateProvider::Freight`, whose rate `metadata` snapshots the summary + deposit terms (frozen at completion — duties doctrine, never re-derived); **deposits are collected, not displayed**: deposit terms → `Cart#amount_due_at_checkout`, `Carts::Complete` validates payments against the deposit (base = order total at placement), order completes `partially_paid` with the existing `outstanding_balance` (2026-08-30 amendment: the method-level `deposit_percentage` is a *default source* feeding the order's `payment_terms` snapshot — see `6.0-6.1-b2b-payment-terms.md`); the forwarder's quote lands later as `Fee(kind: 'freight')` through `/admin/orders/:id/fees`. **Constraints now:** all volume/CBM math goes through the unit-aware helper (raw dimension-column multiplication is forbidden — the `WeightRule` raw-number shortcut does not extend to volume); no new readers of the `default_package_*` preferences; never model quote-later as a zero-cost priced rate; carton geometry never becomes variant columns; nothing may assume a completed order is paid in full (check `payment_status`/`outstanding_balance`); post-placement freight charges are Fees, never delivery-rate edits.
- `6.0-b2b-quantity-rules.md` — B2B MOQ + order multiples + purchase unit (design finalized 2026-08-30 under the one-question-per-entity doctrine — decisions.md): variant base columns `minimum_order_quantity`/`order_multiple`/`purchase_unit` (`unit|carton`, display-only vocabulary — stored quantities stay units) binding every cart, enforced as named steps in `Carts::AddItem`/`UpsertItems` on the RESULTING line quantity and re-checked at `Carts::Complete` (staff/admin unrestricted; server refuses invalid quantities naming the nearest valid neighbors — **never silently rounds**); storefront steppers step by the multiple / count cartons ("2 CTNS — 48 units"). **Commercial terms are Catalog data:** the catalog-wide default = `minimum_order_quantity` + `order_multiple` **columns on `spree_catalogs`** (same pair at three levels: variant base → catalog default → override), contextual per-SKU tiers = `spree_catalog_quantity_rules` (catalog_id, variant_id both null: false, one plain unique index — strictly overrides), and the cart-level minimum = `spree_catalog_order_minimums` (per-currency rows, never one amount + a currency column) — **deliberately typed tables per grain, never one generic catalog_rules table or an STI rule family** (hot-path indexed lookups + DB uniqueness; rules are matching predicates, terms are values — typed-adjustments doctrine), all resolved **per-field nearest-agreement-wins** through `Catalog.for_context` (override row → catalog columns → variant base; a channel minimum is just its default catalog's terms; a terms-only catalog with empty assortment is legitimate); serializers expose the buyer's *resolved* rules + the minimum/shortfall. The earlier same-day `ChannelRule` STI family is superseded — access gating (`storefront_access`/`guest_checkout`) stays as Channel preferences because gating binds before identity exists. **Constraints now:** nothing below the cart layer may read quantity rules (stock/allocation/fulfillment stay unit-pure); new item mutations keep routing through `AddItem`/`UpsertItems`; commercial terms are catalog rows/columns resolved per-field — no purchase-term settings on Channel, no term columns on variants beyond the base rules; never move gating onto catalogs.
- `6.0-price-list-automatic-pricing.md` — Automatic price adjustments (design finalized 2026-08-30): `spree_price_lists.price_adjustment_percentage` (signed decimal, nil = fixed list; `adjust_compare_at` boolean) — the resolver derives base × factor **on read** for variants without an explicit row (explicit amounts override per variant × currency; nil-amount placeholder rows fall through), currency-rounded, currency-agnostic (applies to every base currency), **never materialized** (no refresh jobs, no drift; resolution cache keys must include the base price's version). Combined with `VolumeRule` this gives automatic % volume discounts with zero rows to maintain. **Catalog-owned lists only** (revised 2026-08-31): a percentage has no product scope of its own — the owning catalog's assortment is what scopes it — so `price_adjustment_percentage` is refused on a standalone list by validation, and the Pricing card lives on the catalog page, never the standalone price-list page. A standalone list with no rules, no catalog and no products is refused activation. Product-scoped store-wide percentage discounts are a Promotion's job. **Constraints now:** no job/rake/import may write price rows computed from an adjustment; price exports/feeds/reports must resolve through the pricing provider once adjustment lists exist; "how numbers are made" lives on PriceList, never Catalog.
- `6.0-b2b-customer-po-numbers.md` — Buyer PO reference on orders (design finalized 2026-08-30): `po_number` string on cart + order (industry-exact name; copied at completion; staff may correct post-placement as a plain write — it is not money) + optional **`po_document`** private-storage attachment (direct upload, spoofing-protected, blob re-attached to the order at completion — no competitor has order-native PO upload) + **`po_number_required` boolean on `Spree::Company`** (per-company is the market's control granularity; deliberately NOT a catalog term — buyer process ≠ agreement; not governance, so the OSS-companies constraint holds) enforced as a `Carts::Complete` validation (`code: 'po_number_required'`, staff-created orders skip); `po_number` ransackable + the dashboard order search matches number OR PO; surfaced on admin order page, customer order history, confirmation email, and every future order-facing document. The Enterprise quote plan's `customer_reference`/attachment were replaced by these order fields (amended 2026-08-30). **Constraints now:** never model the buyer PO as a payment method or couple it to tender choice; `po_number` (buyer reference) and `Spree::PurchaseOrder` (merchant procurement, inventory-operations) never mix — no shared endpoints/serializers/vocabulary; new order-facing documents/emails render `po_number` when present; post-placement PO edits never route through the order-change substrate.
- `6.0-draft-order-negotiation-mechanics.md` — Manual line pricing on draft orders + cart→draft copy (design finalized 2026-08-30; **implemented in full 2026-08-30**, including `Orders::CreateFromCart` and the payment-terms plan's payment-number fixes riding along; OSS half of the quotes tier split — the quote product is Enterprise `b2b-quotes.md`). **6.0:** admin item endpoints accept `price` on incomplete orders, stamping **`price_source: 'manual'`** — the provenance column's first readers land as guards (`Carts::PriceItems` skips manual rows, `LineItem#should_update_price?` false for them) so quantity edits stop silently re-pricing negotiated lines; `'manual'` is a reserved key no pricing provider may register; `price: null` = explicit revert; `price_source` exposed admin-only, never on store serializers; plus fixes — `Orders::Create` stamps `created_by`, and the `payment_pending` docstring corrected (completion yields `payment_status: 'none'`, not `'balance_due'`; a distinct unpaid value is the wholesale-deposit rollup work's call). **6.0, late (retargeted 2026-08-30 so Enterprise quotes need nothing beyond 6.0 GA):** `Spree::Orders::CreateFromCart` copies a customer cart into a fresh draft order leaving the cart untouched (not the completion copier — no money re-pointing, no `cart_id` claim). **Constraints now:** nothing reprices a `manual` line except the explicit revert and new repricing call sites must honor the guard; no post-placement price overrides (fees/discounts until the order-change substrate's `update_item_price` kind); quote lifecycle/statuses/expiry/customer surfaces never grow here (Enterprise plan).
- `6.0-b2b-company-self-registration.md` — B2B front door, OSS mechanisms only (design finalized 2026-08-30; **retargeted 6.1 → 6.0 the same day**: the Enterprise onboarding product must ship on 6.0 GA and these small additive mechanisms are its only missing input): `POST /store/companies` (authenticated customer — including an existing retail customer — founds a root company + membership in one call; companies **born active**; registration answers → `metadata['registration']`; `company.registered` event, core sends no mail), fourth storefront access posture **`approval_required`** (prices + checkout need a standing over an active company; `prices_hidden` guest-only semantics untouched), **`pricing_access`** reason code beside every nulled price (`login_required` | `company_required` | policy-supplied), and **`Spree::Companies::ActivationPolicy`** (dependency-registered, default: every company active) consulted by `Catalog.for_company`, BOTH `sole_standing_company`s, cart `company_id` writes and the posture. The approval FLOW (pending lifecycle, requirements checklist mirroring seller onboarding, queue, request-more-info) is **Enterprise** (`spree-enterprise-v2/docs/plans/b2b-company-onboarding.md`) via the policy — no competitor ships approval OSS. **Constraints now:** new company-resolving code (visibility/pricing/checkout) consults the policy and the two `sole_standing_company`s stay mirrored; self-service standing never approval-gated; no status columns on `spree_companies`; no interim approval primitives beside it (customer-group membership prices, never approves); prices-hidden surfaces always carry the `pricing_access` code.
- `6.0-multi-vendor-marketplace.md` — Open-source the marketplace core (Seller, OrderGroup-based order splitting, commission engine with EU commission taxation, `SellerTransfer`/`SellerPayout` ledger + pluggable `PayoutProvider`) per spree/spree#13323. 6.0 headline feature; rebuilds the legacy Enterprise multi-seller module as native models on the Cart/Order split. Basic Stripe Connect payouts (Express onboarding + on-fulfillment transfers) ship OSS in the monorepo, alongside the Stripe core gateway pulled in from the standalone `spree_stripe` repo (payment-sessions classes only, likely `spree/core` — decisions.md 2026-07-15); Enterprise keeps refund clawbacks/netting, reconciliation, KYC ops, DAC7 payout reports, facilitator taxes + Shopify/WooCommerce seller apps. **Seller principal + surface (Decision 10, 2026-08-15):** seller staff are `Spree.admin_user_class` (no `SellerUser`; membership by `RoleUser.resource_type`, never `store_id`) on a dedicated `/api/v3/seller` branch — own `seller_api` JWT audience, own `Spree.seller_authentication_strategies` + `/seller/auth/*`, audience-stamped refresh tokens, every endpoint scope-fetched through `current_seller` (store derived from the seller); sellers never call the Admin API and admin controllers are never subclassed into the seller namespace. **Seller delivery (Decision 13, 2026-09-01 — design only):** delivery profiles, zones and origin groups stay operator-owned (never a `seller_id`; a seller assigns a profile and a product type to their product — shipped 2026-09-01), `DeliveryMethod` gains a nullable `seller_id` + `available_to_sellers`, a seller's package (its stock location's seller) is offered its own methods plus shared marketplace ones — decided in `Stock::Estimator#filter_delivery_methods` and nowhere else; seller methods are internal-rate/manual-fulfillment only (carrier accounts stay the operator's), `DeliveryOriginGroup#covers_location?` is true for seller locations, and `delivery_methods` becomes its own seller-grantable catalog resource.
- `6.0-seller-onboarding-requirements.md` — Operator-configured seller onboarding checklist (design finalized 2026-08-18): `Spree::SellerRequirement` = store-scoped STI rows (`acts_as_list`, `active`/`required`, per-kind preferences) over developer-written kinds registered in `Spree.seller_requirements` (same `registers_subclasses_via` + `PreferenceSchema` types-discovery pattern as `DeliveryMethodRule`); three completion families — computed from seller data, attested by the seller, verified by the operator/a provider — the last two through one persisted `Spree::SellerRequirementSubmission` (`pending | accepted | rejected | waived`, optional private file attachment; generic `Attestation`/`OperatorReview`/`Document` kinds); evaluated on read by `Spree::Sellers::Requirements` into `SellerRequirementStatus` value objects (`complete | incomplete | pending | rejected`), never denormalized onto sellers. **Exactly two enforcement points:** `Sellers::SubmitForReview` (new; `onboarding → ready_for_review`, `auto_approve_sellers` store preference chains into Approve) and `Sellers::Approve` (refuses unless `override_requirements: true`, recorded on the event); post-approval drift is flagged, never enforced (`sellable?` unchanged, payouts gated by the provider). `Sellers::StartOnboarding` on invitation acceptance, `Sellers::ReopenOnboarding` for send-back. Admin API `/admin/seller_requirements` (+`/types`) under `write_sellers`, `include=onboarding` on sellers, submission accept/reject/waive; seller branch `GET /seller/onboarding`, `POST /seller/onboarding/submit_for_review`, `POST /seller/requirements/:id/submissions`. Defaults provisioned per store (`provision_defaults` + seed); empty = nothing required. **Constraints now:** no `Seller#onboarding_completed?`-style methods or step-done columns on `spree_sellers` — new admission checks are kinds (or `validate` hooks on the seller workflows), per-seller check state is a submission; nothing but the two workflows reads the checklist as a gate.
- `6.0-store-policies.md` — Store + seller policy documents (**implemented 2026-08-27**): the missing back-office surface for `Spree::Policy` — Admin API v3 CRUD (five endpoints, `settings` scope, writes take the plain `body`, sanitized on save) + dashboard Settings → Policies page (MediaRichTextEditor, delete confirm, no reorder) — and extend ownership to sellers: `Seller has_many :policies, as: :owner` (no seeding — stores keep their four seeded defaults, sellers start empty), seller-branch CRUD (`Seller::ResourceController` derives the scope; `scoped_resource :seller_profile`), seller panel Settings → Policies page (plain `RichTextEditor` — media embedding is admin-only), new computed `Spree::SellerRequirements::Policy` kind (**one row per document** — `allow_multiple?`, so the row's own `name` is the policy required and two required policies are two separately-tracked lines; matched case/space-insensitively + non-blank body; no preferences; not in `DEFAULT_KINDS`; status exposes `required_policy_name`), store seller serializer exposes policies behind `?expand=policies`, store policy serializer gains `updated_at` (recorded exception to the no-timestamps rule). **Constraints now:** the leaky `Policy.for_store` override is deleted and must never come back — read policies through the owner association (`store.policies` / `seller.policies`), never a class-level scope (the deletion is a prerequisite for seller policies: the override leaked non-store-owned policies into every store's public endpoint); no `kind` enum, `position` column or fixed policy vocabulary (open set is the design); rich-text writes go to the plain attribute — `body_html` is a read-only reader and the `*_html`-on-write line in `6.0-admin-api.md`/`6.0-rich-text-descriptions.md` was wrong and is corrected; nothing persists checkout consent (that's `5.4-6.0-eu-legal-compliance.md` scope); storefront policy links stay hardcoded until a `store/info`-style endpoint embeds the policy list.
- `6.0-cart-order-split.md` — Cart/Order model separation, dual-FK owner everywhere (`cart_id`/`order_id` exactly-one, `#owner` as method — NOT polymorphic), idempotent copy-on-completion (`Order#cart_id` unique, order-before-payment), Order state machine removed (Checkout::Requirements for steps; payment/fulfillment statuses derived-then-persisted via one recompute service). **Shipped to 6-0-dev (feature/6-0-core-rewrite Waves 1+5):** Cart owns checkout end to end, machine + `spree_orders.state` gone, `Carts::Complete` three-phase pipeline live, `Orders::UpdateStatuses` sole status writer; only Wave 7 data migration (incomplete orders → carts) remains
- `6.0-admin-api.md` — Admin REST API conventions, auth, endpoint list (~300 endpoints)
- `6.0-admin-spa.md` — React admin architecture, extension points, table registry, i18n + server-error mapping
- `6.0-admin-rbac.md` — First-class admin RBAC (spree/spree#14164; design finalized 2026-08-07): **one grant system, staff-only**. The permission catalog IS the API-key scope vocabulary (`read_*`/`write_*` per resource; `ApiKey::SCOPES` derives from the catalog; new `staff` pair split from `settings`); **permission sets are deleted at 6.0 with NO bridge** (recorded exception to the bridges convention — `assign` raises an upgrade tripwire; record-level custom rules → `register_ability`). **Roles are pure data** — no code-managed roles, no runtime merge; roles-as-code = seeds or Admin API; extensions register catalog resources, never roles. Enforcement unifies on the key gate for JWT staff AND secret keys (`ScopedAuthorization` generalized); CanCanCan demoted to internal plumbing. DB: JSON key array + `description` + `mutable` on `spree_roles` (admin seeded immutable — NamedType pattern; hosts can lock compliance roles the same way); roles CRUD + `GET /admin/permissions` + `/me.permission_keys` + 403 `details.required_permission`; full-page role editor (`/settings/roles/$roleId`) sharing one PermissionPicker with the API-keys page (client-side templates, no seeds). Storefront has NO roles — customer baseline is internal ability code, scope-fetching is the enforcement; B2B company roles are a separate future Enterprise system (never share the vocabulary); catalog visibility per group/company is data scoping, never a permission key. **Constraints now:** no new `PermissionSets::` classes or `Spree.permissions.assign` calls; models authorized by new admin controllers must be covered by a catalog entry; new sensitive resources get their own catalog resource, never ride `settings`; storefront code never consults `Spree::Role` or the catalog.
- `6.0-product-types.md` — Prototype → ProductType rename, custom-field schema enforcement. **Creation-time template (2026-08-06):** type edits never mutate existing products (custom-field form/validation + `fulfillment_types` are live by reference; option types/categories seed additively at attach; explicit previewed `ApplyToProducts` job is the only bulk path); per-product type detach/reassign allowed (non-destructive), `required` on a type's custom field is **advisory only** (dashboard marker; no server validation — Spree writes product + fields in two steps), no Store API exposure. **Fully shipped** (all phases, Phase 2 rescoped + delivered 2026-08-06)
- `6.0-remove-master-variant.md` — Eliminate is_master, add default_variant_id FK on Product. **Shipped to 6-0-dev (PR #14265):** is_master removed from all models, default_variant_id + `spree:remove_master_variant` data-migration rake landed; only the physical is_master column drop remains (6.1 cleanup).
- `6.0-typed-stock-movements.md` — Replace generic StockMovement with typed kinds (`received`/`allocated`/`shipped`/`released`/`adjusted`) + concrete FKs (`order_id`/`fulfillment_id`/`return_id`/`exchange_id`/`stock_transfer_id`; `purchase_order_id` rides with inventory operations). **Stock leaves the shelf at fulfillment, not at order placement (2026-08-13):** placement writes `allocated` (raising `allocated_count`, `count_on_hand` untouched), dispatch writes `shipped` (decrementing `count_on_hand` and retiring the allocation); allocation is keyed to the fulfillment (never the line item), oversell becomes `allocated_count > count_on_hand` instead of a negative on-hand (so `restock_backordered` and the movement `min_quantity` guard are deleted), and shipping only ever converts an allocation — which is what makes pre-upgrade fulfillments safe. **Also owns the `StockItem` → `StockLevel` rename** (decisions.md 2026-03-17, pulled in 2026-08-13) as Phase 0 — table/prefix (`si_`→`sl_`)/FK (`stock_level_id`)/endpoint (`/stock_levels`)/SDK resource all move, with constant + association + column aliases and dual-emitted `stock_item.*` events for one release. Phases: rename → schema → model/call sites → data task (`spree:migrate_stock_movements_to_typed_rows`, after `migrate_shipping_to_delivery` **and** `migrate_returns`) → API; the polymorphic `originator` drop waits for 6.1 because the task reads it. **Constraints now:** never write `count_on_hand` outside a movement (no new `adjust_count_on_hand`/`set_stock`/`update_all` callers, none of `restock_backordered`), never create `StockMovement` rows directly (use the `StockLocation` verbs), read availability through `Stock::Quantifier` / `StockItem#available_count` rather than raw `count_on_hand`, and build nothing on `originator_type`.
- `6.0-normalize-state-to-status.md` — Rename state → status on Payment, Shipment, InventoryUnit, ReturnAuthorization, GiftCard
- `6.0-document-numbers.md` — Document number customization (**implemented 2026-08-13**): `Spree::Core::NumberGenerator` module factory → **`has_spree_number prefix: 'R'`** (macro from `Spree::HasNumber`, included into `Spree::Base` — no per-model include) + runtime `Spree.number_generators` registry (`Sequential` | `Random` strategies). **Sequential is the 6.0 default** (per-`(store, resource_type)` `spree_number_sequences` counter, `with_lock`, start 1001), random opt-in; merchant settings = one "Order numbers" card (prefix/suffix/format/start as Store preferences) — orders only. Fulfillment + Payment numbers become **derived methods** (`R1001-F1`/`R1001-P1`; stored value honored on legacy rows, columns frozen — never write them; gateway `order_id` = `payment.number`); every other numbered model keeps its stored number (Import/Export mail theirs, so they stayed numbered too), and `Spree::PurchaseOrder` must be born with `has_spree_number prefix: 'PO'`. Saving a numbered record with `validate: false` requires calling `generate_number` first. Never parse/regex a `number`; mostly-gapless, never legal invoice numbering.
- `6.0-delivery-profiles.md` — **Implemented in PR #14404 (2026-08-09).** `Spree::DeliveryProfile` = ShippingCategory promoted via table rename (`spree_shipping_categories`→`spree_delivery_profiles`, `products.shipping_category_id`→`delivery_profile_id`): store-scoped STI (kinds `DeliveryProfiles::Shipping`/`::Digital` via `Spree.delivery_profile_types`), one default per store, products reference it directly and it's required (auto-assigned: type template else store default; ProductType stamps at creation only — template doctrine). Profile ↔ stock locations (origins, empty=all) + profile→zones + profile→methods; method binds ≤1 zone (m:n join dropped), optional ships-from narrowing per method (no location-group layer — considered, dropped). **Classes only, NO string vocabularies:** method `fulfillment_type` column dropped, `Spree.fulfillment_types` registry + ProductType array deleted; behavior = `FulfillmentProvider` class predicates (`digital?`/`pickup?`/`pickup_point?`/`requires_address?`), rate-provider `requires_address?`, profile kind `digital?`/`requires_shipping_address?` + composition validations. Carts split per profile (`Splitter::DeliveryProfile`); Coordinator allocates only from profile-covered locations. `spree:migrate_delivery_profiles` (5.6→6.0 manifest) does store assignment/kind detection/non-narrowing fold-in/method m:n collapse (`spree_shipping_method_categories` survives to 6.1 as source). ShippingCategory/ShippingMethodCategory classes + associations deleted. Supersedes the string-registry + "named groups 6.1" decisions.
- `6.0-fulfillment-and-delivery.md` — Shipment→Fulfillment, ShippingMethod→DeliveryMethod, drop ShippingCategory, FulfillmentProvider strategy, pickup (merchant StockLocation) + pickup_point (third-party PickupPointProvider). **Shipped to 6-0-dev (Waves 2+4+6):** renames + deprecated twins, providers (Manual/Digital/Pickup/PickupPoint), dual-emit events, store pickup discovery endpoints, admin delivery_methods/delivery_zones CRUD + dashboard settings pages, FulfillmentMailer; Wave 7 shipping→delivery data migration remains. Pickup work beyond shipped code deferred to 6.1 (2026-08-06): contract hardening (`new(delivery_method)` ctor, `find_nearby` zipcode/query) + how-to guide; `PickupPointProvider::Base` stays **undocumented in 6.0** (v6 docs cover only the delivery rate provider interface) — never add pickup-provider docs in 6.0 work. Delivery mechanics live on provider classes (`pickup_point` provider ships but stays unregistered until 6.1; `local_delivery` cut = shipping + postal-code zone); the string fulfillment-type registry was deleted by `6.0-delivery-profiles.md`. **Partial fulfillment (2026-08-10, resolved question 12):** shipping a subset is `Spree::Fulfillments::Fulfill` (optional per-line-item `items:` + `tracking:` + `notify_customer:`; splits then fulfills in one transaction) — never a state-machine event, since split-then-ship in an `after_transition` is what service-workflows prohibits. **Side effects left the machine (2026-08-10, question 13):** `after_cancel`/`after_resume` are gone as transition callbacks — restock + carrier stand-down live in `Fulfillments::Cancel`/`::Resume` as inline steps (provider call is an `external_step`; `notify_provider: false` lets `Orders::Cancel` delegate and batch carrier I/O after its own transaction), `after_cancel`/`after_resume` are deprecated shells and the only trace left on the model — never add public model methods for workflows to call. **Status model (2026-08-11, question 14): the machine is REMOVED.** `status` = plain `HasStatus` `unfulfilled → fulfilled → delivered | canceled` (`pending`/`ready`/`ready_for_pickup` collapse — payment/stock gating is a `Fulfillments::Fulfill` validate guard, pickup renders modality-aware labels); `delivered` = confirmed receipt (`Fulfillments::MarkDelivered`, `delivered_at`, `fulfillment.delivered`) — the returns window + EU withdrawal anchor; carrier truth is the separate `tracking_status` axis (data, never a machine) written by `Fulfillments::UpdateTracking`, fed by EasyPost tracker webhooks (opt-in trackers for hand-entered numbers). Rollup domain `backorder | canceled | partial | unfulfilled | fulfilled | delivered`. **Phase 7 shipped 2026-08-11** (core + API + dashboard + EasyPost tracker webhook + `spree:migrate_fulfillment_statuses`); **label leads, fulfilled follows (2026-08-12):** `Fulfillments::PurchaseLabel` = explicit pre-ship label buy (loud failure, no email); `Fulfill` buys label BEFORE marking fulfilled (email always carries tracking; post-split failure keeps the split, never rolls it back); providers declare `generates_labels?` + idempotent `create_fulfillment`. **One tracking number per fulfillment (2026-08-11, question 15):** diverging parcels are split fulfillments; a `spree_fulfillment_trackings` model is 6.1 work and must absorb the entire carrier axis (per-row status/`delivered_at`, webhook matching by row) — never split the axis across fulfillment and tracking rows
- `6.0-digital-assets.md` — **Waves 1–6 SHIPPED and merging in 6.0 (waves 1–5 2026-08-10, hardened 2026-08-12; wave 6 provider-backed assets 2026-08-12; OpenAPI regenerated + dashboard E2E added 2026-08-27, branch mergeable); wave 7 (license-code pools) DEFERRED to 6.1 — design finalized 2026-08-12, purely additive (new table + provider on the shipped wave-6 mechanism, no wave-1–6 behavior change).** `Spree::Digital` → `Spree::DigitalAsset` (table + FK renamed; `DigitalLink` keeps its name) with one-release bridges: constant alias, deprecated `digitals` twins, dual-emitted `digital.*` events, `PermittedAttributes.digital_attributes`, legacy `store/digitals/:token` route. Shipped: Admin API v3 (assets nested under products with private-storage direct upload, `digital_links` read + `reset`, order `resend_digital_links`; catalog — assets ride `products`, links ride `orders`), dashboard (product Digital files card, order links card, store Downloads settings), `Spree::DigitalAssetMailer#files_ready_email` on `order.placed` (+ resend), customer `GET /store/customers/me/digital_links` + store SDK resource, `digital_link.downloaded` event (no log table), signed-URL download transport clamped to the link's own expiry with `digital_asset_link_expire_time` capped at 1h, phantom `:digital` product param removed. Per-asset nullable `authorized_clicks`/`authorized_days` fall back to store settings — a recorded exception to the store-scoped-configuration no-fallback rule. **Wave 6 (shipped 2026-08-12):** NO `kind` column — the provider IS the discriminator. A single nullable `provider_type` (class name); blank resolves to `Spree::DigitalAssetProvider::File` (the default, = today's signed-URL behaviour), a class name to that provider — exactly like `DeliveryMethod#provider_class`. Validation/metadata/create-form key off `provider_class` (which declares `requires_attachment?`), never a string. **No `Spree::Integration` binding** (deliberately unlike delivery-rate/tax providers, which connect marketplace services): a digital-asset provider is bespoke glue into one company's internal legacy software, host-app code that self-configures — no `integration_id`, no `requires_integration?`, no picker. `download_url` generalizes to `deliver` returning a `Spree::DigitalDelivery` value object (redirect URL **or** inline value like a license key). Registered via `Spree.digital_asset_providers`; core ships only the `File` provider. Link-per-unit with resolve-on-download; a provider failure returns 403 without spending the click. **Per-asset provider settings (shipped 2026-08-12):** shared config (endpoint/credential) stays the provider's own concern; *per-asset* config (which pool, which external SKU) is declared with a class-level `setting :key, :type` DSL (`Base.settings_schema` = the `PreferenceSchema` wire shape, but NOT `Preferable` — the provider is a stateless per-call strategy) and stored on the asset in `metadata['provider']` (`DigitalAsset` gained `Spree::Metadata` + a `metadata` column; `provider_settings` accessor), read in `deliver` via `digital_asset.provider_settings`. Primitive field types only (`:string`/`:number`/`:boolean`/`:select`); the `providers` discovery endpoint carries `settings_schema`; the dashboard renders a generic sheet — no provider ships React. **Constraints now:** new code uses `DigitalAsset`/`digital_assets` names only; **nothing outside the model may assume an attachment is present — reach for `deliver`/`downloadable?`, never `attachment`** (a provider-backed asset has none); download-flow code treats the deliverable as opaque; **do NOT add an `Integration` FK/credential surface to `DigitalAsset`** (providers self-configure); shared credentials/endpoints are never a `setting` (per-asset values only) and provider settings stay namespaced under `metadata['provider']`; emailed download URLs keep resolving across renames one release; the generated OpenAPI specs were regenerated 2026-08-27 (reproducible swaggerize). **Wave 7 (DEFERRED to 6.1, OPEN SOURCE):** license-code pools — the "sell game keys" feature. `Spree::LicenseCode` (belongs to a `DigitalAsset`; a `value` string OR an attached scan/photo; nullable `digital_link_id` = redeemed state) + a `LicensePool` provider built on the shipped wave-6 provider mechanism (text → `inline_value`, image → `redirect_url`). CSV import via `Spree::Import` (text codes only; images upload individually). **Claim-once-pin-to-link:** first download claims a code and pins it, later views re-show the SAME code (click limit caps views, never burns a second code). **Pool count IS the variant's stock** — `count_on_hand` synced to `codes.available.count` so it sells out via the existing `can_supply?` path (a real `Stock::Quantifier` integration — a digital variant returns INFINITY today, a pool variant must return its finite count). **Constraint:** keep `count_on_hand` and unredeemed-code count in sync **transactionally** on import + redeem — drift blocks stock or oversells; never compute lazily in checkout.
- `6.0-returns-exchanges-claims.md` — First-class Return, Exchange, Claim models replacing ReturnAuthorization/Reimbursement chain. **COMPLETE (2026-08-05):** all three entities (+ permanent `ReturnLineItem`/`ExchangeLineItem`/`ClaimLineItem` line items), `Spree::HasStatus`, all fifteen workflows (each with a leading `validate` hook), `Refund#originator`, admin + store v3 APIs (transitions as PATCH member actions; no destroy — cancel instead), dashboard pages. Legacy chain **removed**: ReturnAuthorization/CustomerReturn/Reimbursement/ReimbursementType/legacy ReturnItem + eligibility validators + ReturnsCalculator classes all deleted, but their **tables deliberately survive to 6.1** as the data migration's source and rollback path. `spree:upgrade:migrate_returns` (`Spree::ReturnsMigrator`, defined in the rake file like its sibling upgrade tasks; anonymous-AR readers) is in the 5.6→6.0 manifest after the adjustments step; it needs no cursor because the preserved `number` is uniquely indexed on the new tables, so "what's left" is a `where.not(number: ...)` query and an interrupted run resumes for free. `ReturnAuthorizationReason`→`ReturnReason` (alias one release) + new `ClaimReason`; `Metafields` on all three. Capability replacements: `Spree::ReturnMailer#refunded_email` on `return.refunded` (replaces the reimbursement email), `Order#outstanding_balance` drops the reimbursement term (refunds already net out of `payment_total`), `Return#refunded_total` counts store credits too, store credit issued with `originator` + `memo` only (categories dropped 2026-08-18). **Reasons** ship admin-only CRUD (`/api/v3/admin/{return,claim,refund}_reasons`, `settings` scope) + a combined Settings → Reasons dashboard page + reason pickers on the create dialogs; `mutable` is never client-writable and the immutability guard lives on `Spree::NamedType` (`can_be_deleted?` + rename/destroy guards) because secret API keys authorize by scope and never consult CanCanCan. **No state machines (2026-08-02):** plain `status` string + inclusion validation; all fifteen transitions are workflows (`Returns::Receive`, `Exchanges::Fulfill`, `Claims::Resolve`, …) with `validate` hooks for return-eligibility policy and refunds as `external_step`. Nothing happens in a model or transition callback. Statuses live in a `class_attribute` via the core `Spree::HasStatus` concern (`has_status` + additive `add_status(value, after:)`, generating predicates and scopes) — extensible by design, additive only, and no transition graph (that would be a state machine again). **Return eligibility is a hook, not a policy engine (2026-08-03):** no window/restocking-fee/final-sale flag in core — a `validate` handler decides, enforcing for customers while letting staff override (it reads `created_by`), and region-varying policy reads `order.market`. Medusa/Saleor/Vendure ship no policy at all; Shopify's engine has no API. A `ReturnPolicy` model can arrive later behind the same hook.
- `6.0-platform-auth.md` — Drop Devise, own auth stack, User→Customer/Staff rename (RefreshToken shipped in 5.4)
- `6.0-store-context-and-first-run-setup.md` — Store context becomes credential-derived (design finalized 2026-08-13): publishable key selects the store on the Store API, Admin API honors `X-Spree-Store-Id` with membership checked against the *requested* store (header-less JWT → default store + deprecation, required 6.1), hostname-based store resolution retired (`FindDefault`'s `url:` is dead; never read `request.host` to pick a store). First-run setup replaces the `spree@example.com`/`spree123` dummy seed: seed creates an admin only when `ADMIN_EMAIL`/`ADMIN_PASSWORD` are explicitly set; otherwise a one-time setup-token flow (dashboard `/setup` + unauthenticated `auth/setup` endpoints; `has_secure_token :setup_token` on Store — plaintext like invitation tokens, printed by installer, `spree:setup:token` reprints, cleared on completion — required in EVERY environment; `Spree::Stores::DashboardUrl` is the single resolver for the dashboard origin — used by the setup link, invitation emails and the SSO callback — resolving `dashboard_url` pref/`SPREE_DASHBOARD_URL` → deprecated `admin_url` → this app's own `/dashboard` mount when `spree_dashboard` serves a build → dev Vite → store URL; never a hardcoded port, and the CLI rebuilds the link host-side since the seed runs before any dashboard is up). **App configuration reads ENV:** `RuntimeConfiguration.preference` accepts `env:` (precedence: explicit value → env var → coded default), so deployment settings are configurable without touching Ruby; `dashboard_url` is env-backed via `SPREE_DASHBOARD_URL` and `admin_url` is deprecated in its favour. Applies to `Spree::Config` only — per-store behavior belongs in Store preferences. The setup flow creates the first admin and adopts/renames the seeded store; no general store CRUD in the OSS Admin API. **Constraints now:** never assume `current_store == Store.default` in Admin API code; store-touching cache keys include the store id by construction (enforced by the cache-key audit spec in core — global data needs a reviewed allowlist entry); new scripts pass `ADMIN_EMAIL`/`ADMIN_PASSWORD` explicitly. **Isolation tripwires (2026-08-13):** `Spree::StoreScopeGuard` wraps every v3 API request in dev/test and flags store-less secondary-key lookups and unscoped scans on store-owned tables (schema-derived set; id/FK filters and `SELECT 1 AS one` are exempt as loads-from-scoped-rows and uniqueness validations — exemption is NOT proof of scoping, request-derived ids still need `current_store` fetching; `log` default, `raise` in this repo's API suite, `SPREE_STORE_SCOPE_GUARD` to change) — wrap deliberately global lookups in `Spree::StoreScopeGuard.skip { }`. A store-owned model with an unscoped `acts_as_list` also fails the core suite (positions bleed across stores). **Country-aware setup (2026-08-15, shipped):** setup asks for `country_code` (required) plus `locale` (country's official languages, filtered to those Spree translates, + English) and `currency` — both optional to the endpoint and defaulted from the country, both editable in the form; an unresolvable currency is a pre-token-spend 422, never silently ignored. Country data from unauthenticated `GET auth/setup/countries`. `Spree::Stores::ProvisionDefaults.call(store:, country:, locale:, currency:)` owns every country-derived per-store default (bootstrap market updated in place, warehouse country, Domestic/International zones + flat rates, pickup method — all in the derived currency) and absorbs the `StockLocations`/`DeliveryZones`/`PickupDelivery` seeds; exactly two callers — the setup endpoint and `Seeds::AdminUser`'s env branch (`STORE_COUNTRY`/`STORE_LOCALE`/`STORE_CURRENCY`, defaults `US`/`en`). It also restates seeded zero-amount rates (digital delivery) into the store currency. Sample data builds around the default market, never resets it. **Constraints:** a store's country changes through its **market**, never `Store#default_country_code=` (on a store with a market that writer is a dead column — readers delegate to the market, the after_update sync copies locale/currency only); country- or currency-dependent seeds go into `ProvisionDefaults`, not `Seeds::All`; never give the service a third caller.
- `6.0-tax-provider.md` — Per-Market TaxProvider (market selects the provider, providers stateless/argless; global config class stays as fallback), replaces TaxRate.adjust + Calculator; reference provider: Avalara (decisions.md 2026-07-30). **Shipped to 6-0-dev (core-rewrite waves):** `Spree::TaxProvider::Base`/`Internal` as the sole TaxLine write path, called from `Carts::RecalculateTotals` behind the `money_frozen?` freeze. **Contract refined 2026-08-05 after the spree/spree#14056 review (decisions.md):** TaxLine gains `taxability_reason` + jurisdiction snapshot (e-invoice category/exemption codes derived at invoicing time, never stored); new `Spree::TaxIdentifier` model (customer/cart/order dual-FK, frozen order snapshot; validation via the kind-keyed `Spree.tax_id_validators` registry + async job on the geocoding precedent — NOT a provider method, and no registry client in core); exemptions = typed `estimate` input via `tax_resolve_exemptions_service` (boolean `exempt?` removed, no flags anywhere); explicit `tax_date:`; `refund(order, return_items, tax_date:)`; capability declarations (Internal declares no US local tax / no reverse charge / no one-stop-shop thresholds; `estimate` keeps its no-op return — a structured result + indeterminacy channel deferred as safely additive). **Phases 3-5 in development:** the enriched contract, `Spree::TaxIdentifier` + validator registry, exemption value objects, per-Market selection with commit/void/refund as external steps, and the Zone decoupling (rates carry `country_code`/`state_code` — codes, not FKs, since Country/State are being dropped; `spree_tax_rates.zone_id` stays through 6.0 as the conversion source). **Phases 3-5 + the Zone decoupling shipped to `feature/v-3526` (PR #14410).** **Phase 7 shipped to `feature/v-3526` (2026-08-12):** the minimal Company tree pulled forward out of the B2B plan — `company_id` as a fourth TaxIdentifier owner, `Spree::TaxExemptionCertificate` hanging off Company scoped by `country_code`/`state_code`, and the `ResolveExemptions` body; **no `tax_exempt` boolean anywhere**. That Company→CompanyLocation→CompanyContact shape was **replaced unreleased by `6.0-b2b-companies-and-catalogs.md`** (2026-08-25): purchases carry `company_id` (any tree node) and tax reads anchor on `company_legal_entity`. A buyer's company resolves only within the sale's own store, since customers are global. Pending after that: Phase 6 `spree_tax_avalara`, **Phase 8 cross-border pricing with tax-inclusive prices** (2026-08-11 live pass: `Pricing::Context.from_order` never carried the cart's market so market-scoped price lists were unreachable from a cart; `recalculate_for_address_change!` called the non-persisting `update_price`; restatement was applied even to prices set for the destination — the rule is now derive net-fixed unless the winning price list carries a `geographic?` rule, Shopify's model), Phase 9 6.1 cleanup (drop `zone_id`, `null: false` on the tax `store_id`s, decide `Market#tax_inclusive`). Still open: delivery-rate tax display bypasses the provider
- `6.0-delivery-rate-provider.md` — Per-DeliveryMethod DeliveryRateProvider wrapping Stock::Estimator (calculators stay — 2026-07-27 reversal), `store_id` on ShippingMethod; monorepo ships one reference multi-carrier provider (**EasyPost** — decisions.md 2026-08-06 reversal: BYOCA fit for larger merchants + only maintained official Ruby SDK; Shippo's ruby gem dead since 2020); method rows stay regional (no cross-market method entity). **Dynamic carrier rates (2026-08-09):** a carrier method is the carrier connection — `estimates(package)` returns one Estimate per service, each becoming its own named DeliveryRate (unique (fulfillment, method) rate index dropped; `DeliveryRate#name` falls back to the method name); `Spree::DeliveryMethodService` rows narrow/rename/mark-up services (no rows = all, method-level markup columns as default); selection + EasyPost label buy key off the selected rate's carrier/service; seeds/sample data reshaped Shopify-style (Domestic + International zones with basic methods)
- `6.0-delivery-zones.md` — Zone → DeliveryZone with postal-code-range/prefix members (country-scoped); owns the full ~183-reference Zone consumer inventory; `Spree::Zone` dropped entirely by end of 6.0 (2026-07-27 — 6.0 is the breaking-change window) Member FKs convert to `country_code`/`state_code` strings per `6.0-drop-country-state-models.md` (2026-08-07)
- `6.0-drop-country-state-models.md` — Delete the `Spree::Country`/`Spree::State` AR models in 6.0 (the tables and legacy FK columns survive to 6.1 as the upgrade task's source data); constants survive as `countries`-gem-backed value objects (carmen removed), consumers store `country_code` + `state_code` strings (always paired — subdivision codes aren't globally unique), Address validation semantics preserved (`STATES_REQUIRED` constants become runtime source of truth). No `id` was ever exposed, so the only v3 changes are the `state_abbr`→`state_code` and `country_iso`→`country_code` renames (Market's list moves `country_isos`→`country_codes`) — `Spree::Address` alone keeps `state_abbr` and `country_iso` as deprecated read/write bridges until 6.1. Amends tax-provider Phase 5 (TaxRate columns born as ISO strings, not FKs) and delivery-zone members. **Shipped (2026-08-14):** value objects live, carmen + country/state seeds + row-creating fallbacks deleted; `Spree::IsoData` curated registry + drift-guard spec, ISO columns on addresses/delivery-zone-members/market-countries/stock-locations/stores with `spree:upgrade:migrate_country_state_codes` in the 5.6→6.0 manifest, every consumer matching on codes, admin FK params closed, country endpoints uncached, factories built from real ISO data. `Spree::Zone`/`ZoneMember` are migration-only shells (no `zoneable` association; the data tasks resolve member ids against the legacy tables via SQL) and drop in 6.1 with the tables. **Constraint now:** no new `country_id`/`state_id` FKs or `belongs_to :country/:state` anywhere — a new model carrying geography declares `has_iso_geography` (`Spree::HasIsoGeography`, on `Spree::Base`; `state: false` for country-only tables) and stores ISO strings in columns named `country_code` + `state_code` — never `country_iso` or `state_abbr`; preference-based rules follow `Promotion::Rules::Country`
- `6.0-integrations-admin.md` — **Implemented (2026-08-06).** `Spree::Integration` as the single credential surface for all provider seams (delivery rates/tax/fulfillment/pickup points): explicit `Spree.integrations` registry, Admin API v3 CRUD + types discovery (reusing `PreferenceSchema`/`Masking` — secrets are `:password` preferences), dashboard `/settings/integrations` gallery grouped by `integration_group`. Verify-before-activate (`active: true` runs `can_connect?`, 422 on failure), ephemeral connection status. Constraints now: provider gems ship an Integration subclass (no env-var credential contracts for per-store providers); no per-provider credential UIs — pickers deep-link to the integrations page.
- `6.0-rich-text-descriptions.md` — Drop ActionText **entirely** at 6.0 (incl. CustomFields::RichText values + Order/User internal notes; gem dependency removed), store sanitized HTML in text columns, serve `field` + `field_html`, **write via `field_html`** (read/write symmetry). description_html serializer shipped 5.4; sanitizer shipped in **5.6.2** with a permissive-but-safe configurable allowlist + `sanitize_rich_text` step in the 5.5→5.6 upgrade manifest (decisions.md 2026-07-27/28), tightened to the Tiptap set at 6.0
- `6.0-media-library.md` — Store-wide media library over `Spree::Media` (**shipped 2026-08-24**): `store_id` on `spree_media` (backfilled from the viewable's product; upgrade task in the 5.6→6.0 manifest), upload-first unattached rows (`viewable_id: nil`), dashboard library page + picker. **Reuse = blob sharing, never a shared asset entity:** copying to another product duplicates the `Media` row and attaches the same blob (`Media#duplicate_for`; `source_media_id` accepted by BOTH the nested media create and the inline `media:` list on the product — the dashboard Save uses the latter), a copy takes the **target's** store (never the source's — `duplicate_for` leaves `store_id` unset so `SingleStoreResource` reads it from the new owner), bare attachment fields (category/collection/store/seller images) adopt files via the blob's `signed_id` through their unchanged endpoints, and deletion safety rests on the Rails `active_storage_attachments`→blobs FK + `PurgeJob` discard — that FK is load-bearing (the no-FK rule covers Spree tables only), and media paths always `purge_later`, never synchronous `purge`. Rich text editor gains image embedding: Tiptap Image + `img` in `RichTextSanitizer.allowed_tags` land in the SAME change (plain `<img>` URLs to a new non-cropping `embed` rendition; no reference-tracking tables) — `MediaRichTextEditor` is the wired component every description field uses, the bare `RichTextEditor` has no picker. `Spree::Media::Usage` answers "where is this file used" from the blob's attachments plus a best-effort search of `SanitizableRichText.declaring_models`. **Category/Collection are real viewables (2026-08-24):** `Spree.media_viewable_types` = Product | Variant | Category | Collection (engine registry, append from an initializer); their `image`/`square_image` slots reconcile into placements via `Spree::HasLibraryMedia` (slots stay the operational storage; clearing a slot UNPLACES the row, never destroys; `spree:upgrade:backfill_library_media_placements` in the manifest) — until a real category gallery exists, reconciliation owns every placement on those records, so never create Media rows on a category by another path. **Media is its own permission resource** (`read_media`/`write_media`, catalog group): the library endpoints (index/show/update/destroy/usage) require it, while the product-nested gallery routes keep `products` — reaching a file through a product the caller already sees is not the same as enumerating the library (Shopify's split). Every attachment-creating path must check the media key, not just the endpoints. Library `DELETE /admin/media/:id` returns 422 + usage list while the file is in use; `detach=true` runs `Spree::Media::Destroy` (removes it from every placement + plain attachment in its store, then purges) — the dashboard sends it after a confirmation. Only the nested gallery destroy removes a single placement. Sellers/stores stay bare attachments (branding, not merchandising). **Constraints now:** no attachment-style join tables onto `Media` (a new context gets its own row sharing the blob); don't add `img` to the sanitizer ahead of the editor node; a new media write path must accept `source_media_id` or reuse silently drops on it; a new viewable type is appended to `Spree.media_viewable_types` deliberately, never by writing the polymorphic column; embedding is opt-in per editor in the dashboard (`MediaRichTextEditor`), never a server-side model list.
- `6.0-inventory-operations.md` — StockTransfer lifecycle (draft → ready_to_ship → in_transit → received with partial receive), new `Spree::PurchaseOrder` + `Spree::Supplier` (the procurement source; `Spree::Seller` is the marketplace seller — see decisions.md 2026-07-14 and 2026-08-17) replacing today's "external receive" hack, variant + stock-location stock history panels. Consumes the typed-movement primitives from `6.0-typed-stock-movements.md`. **Lot-level inventory added 2026-08-30, targeted 6.1** (scope trim — purely additive, opt-in; full tracking chosen over provenance-only): `Spree::StockLot` = per-(location, variant) quantity bucket (`lot_number`, nullable `expires_at`), opt-in via `lot_tracked` on the variant; lot quantities are a decomposition of `count_on_hand` kept in sync **transactionally** with typed movements (license-pool discipline — movements gain nullable `stock_lot_id`, one row per lot touched); receives assign lots (lot-tracked items refuse receipt without lot data), `allocated` stays lot-agnostic, dispatch picks **FEFO** with per-fulfillment override; no storefront exposure. **Constraint now:** lot numbers live only on `Spree::StockLot` — never as strings on line items/fulfillments/movements, and a lot quantity never changes outside its movement's transaction.
- `6.0-replace-taxons-with-categories.md` — Split Taxon into Category (hierarchy) + Collection (flat/rule-based). **Shipped to 6-0-dev (PR #14302):** the Category surface (5.5–5.6) plus the 6.0 core — `spree_taxons`→`spree_categories` table rename + inheritance flip (`Spree::Category < Spree.base_class`, `Spree::Taxon` alias kept), the full `Collection` stack (model + rules + DB/Meilisearch manual sort + API), the taxon→category/collection data migration, and de-ruling Category. Pending (all 6.1): channel-aware `CollectionRules::AvailableOn` (ships interim now, rides with channels) + dropping `spree_taxon_rules`/`Taxonomy`. No brand feature in 6.0 — brands are modeled as a Category/Collection; `brand_taxon`/`brand_name` removed with `Taxonomy`.
- `6.0-delivery-method-rules.md` — `Spree::DeliveryMethodRule` STI on DeliveryMethod (design finalized 2026-07-29): ItemTotal/Weight rules first (Channel/Market/CustomerGroup later in lockstep with payment-method-rules), enforced solely in `Stock::Estimator`'s method filter so calculator- AND provider-priced methods obey eligibility; replaces the FlatRate-only bound preferences (one-release bridge + data task). **Phase 1 shipped** (rules + Estimator seam + admin nested CRUD/types discovery + dashboard Conditions card). **2026-08-06:** `ExcludedProductsRule` (products via `spree_delivery_method_rule_products` join, Saleor-style method-side exclusion) replaces the dropped `spree_products.excluded_delivery_method_ids` JSON column; rule-reference storage picks by cardinality — small reference sets stay `normalize_id_preference` arrays, catalog-scale (products) gets a join table.
- `6.0-service-workflows.md` — Two-tier services doctrine (2026-07-30). **Tier 1 `app/services/`:** plain `ServiceModule` classes, hand-written `def call(cart:, ...)`, Ruby kwargs as the contract — the permanent default; no DSL, no new `run`-pipelines, no hand-rolled sagas. **Tier 2 `app/workflows/`:** `Spree::Workflow` — named steps inside a plain `def perform(order:, ...)` (the ActiveJob::Continuable shape; bare `super` turns parameters into readers). Vocabulary: `step`/`external_step` (+ `with:`, `on_flow_failure:`), `run_hooks` + class-level `hooks`, `failure`/`halt!`; plain `ApplicationRecord.transaction`/`with_lock`/`rescue`/`publish_event`; every step instrumented as `step.spree_workflow`. Money lives in `Carts::RecalculateTotals` (single totals seam; the completed-order branch is the post-placement re-sum — rows re-summed, never regenerated), statuses in `Orders::UpdateStatuses` (refreshes each fulfillment's state, then rolls up); Order/CartUpdater are 6.1-removed warning shells. Shared Cart/Order surface lives in `Spree::Purchase::*` concerns; completion side effects (newsletter, account creation, risk) run in the sync `OrderPlacedSubscriber` on order.placed. Reserved for flows needing hooks, compensation/external I/O, or replay — currently `Carts::Complete`, `Carts::AddItem`, `Carts::Recalculate`, `Carts::RecalculateTotals` (+ order twins) and `Orders::Cancel` (absorbed `Order#after_cancel`; gateway settlement is an external_step). A service graduates to the workflow tier when it earns a hook, never speculatively — but hooks on flows already in the tier ship deliberately on the 6.0 boundary (2026-08-02), since hook keys are public API and moving one later is breaking. **New models get no state machine** — plain `status` string + inclusion validation, transitions through workflows; gateway I/O never in a save callback. Three hook families, contracts settled 2026-08-02: **lifecycle** (past tense, read-only), **validate** (handler calls `workflow.reject!(message)` to veto), **context** (`set_*_context`/`get_provider_data` — handler returns a hash, `run_hooks` deep-merges all handlers and returns it; last writer wins on collision). Phase 3 **shipped (2026-08-02)**: `run_hooks` returns the merged hash and `Workflow#reject!` is public API; `validate`/context/lifecycle hooks live on AddItem, Complete, Recalculate, RecalculateTotals, Cancel and Resume; `Fulfillments::Create`, `Payments::Capture`/`Refund`, `Payments::HandleWebhook` and `Carts::Merge` moved to `app/workflows/` (seams `fulfillment_create_workflow`, `payment_capture_workflow`, `payment_refund_workflow`, `payments_handle_webhook_workflow`, `cart_merge_workflow`; legacy names readable one release). **Customer registration (2026-08-05):** `Customers::Create` (seam `customer_create_workflow`, hooks `customers.create.validate`/`after_create`) is the single storefront customer-creation flow — self-registration + checkout account box (optional `order:` adopts addresses and links the order); absorbs `Orders::CreateUserAccount` (deprecated shell); admin create stays plain CRUD; token issuance stays in controllers; core sends NO welcome email — signup email is host-app code on `user.created` or the `after_create` hook. **Payment flows live in the workflows (2026-08-18, supersedes “money movement stays in the model”):** `Payments::Capture`/`Void`/`Process` implement capture, void and authorize/purchase inline as named steps — Capture/Process claim atomically BEFORE the gateway (a stale instance must not re-drive money movement), while Void stays gateway-authoritative (no pre-claim — the gateway decides if the authorization can still be released) with a compare-and-swap on the terminal write only; `Spree::Payment` keeps only gateway mechanics (`gateway_options`, `handle_response`, error translation) plus deprecated verb shells (`capture!`, `void_transaction!`, `process!`, `authorize!`, `purchase!`) that delegate to the workflows **until 7.0** (a full major — they have been the public money-movement API since Spree 1 and the replacement is a different shape) — new callers use `Spree.payment_*_workflow`, never the shells. `confirm!` stays on the model by design: it runs inside `settle_payment!`'s lock, where workflows cannot go, and makes no gateway call. No workflows for plain CRUD. Workflow Dependencies seams use `*_workflow` keys; legacy `*_service` names stay settable/readable with warnings until 6.1 but writes are stashed, never applied (old service classes aren't workflow-contract compatible). `Carts::Complete` battery must pass unmodified. **Durability = plain Rails:** long-running background work uses `ActiveJob::Continuable` directly (reference: `Spree::Imports::ProcessJob` — CSV spine with a row-number cursor; `CreateRowsJob`/`ProcessRowsJob` deprecated shells); workflows are synchronous request-cycle flows and are NOT jobs — Workflow-level durable execution ships only if the payout run proves the need.
- `6.0-extendable-validations.md` — Workflow `validate` hooks are THE validation extension surface; **no generic model-validation registry** (design finalized 2026-08-13 — decorators stay the documented additive path, relaxing core rules = store preferences/predicate overrides). Ships: `Carts::UpsertItems` graduated to a workflow absorbing every non-increment item mutation (bulk payloads, PATCH quantity, DELETE = quantity 0; per-item `validate` with `AddItem`-compatible readers, shared item-application steps, ONE recalculate per batch; **partial-success on the storefront** — rejected items skip onto the cart's existing `warnings` array on 2xx, while the **order twin fails the whole batch**; no whole-batch veto; `SetQuantity`/`RemoveLineItem` → deprecated shells), `Products::Create`/`Update`/`Destroy` workflows (all write paths route through: Admin API v3, CSV importer, seeds; no standalone variant workflow), **rejections carry `ActiveModel::Errors`** (`Workflow#errors` + argument-less `reject!` rendering via `render_validation_error`; `reject!(message)` bridges to `:base`), `Spree.hooks.validate!` wired into boot, Address polish (document `Spree.validators.addresses` + removal API, `require_company` store preference). Address and cart creation get NO workflow (plain CRUD); custom-field value validation deferred to its own plan (Shopify-style per-definition rules, new-writes-only; `required` stays advisory). **Constraints now:** new item mutations route through `AddItem`/`UpsertItems`, new product write paths call the `Products::*` workflows, no hardcoded error codes at hook-bearing `render_service_error` call sites, clients must check `warnings` on storefront bulk-item 2xx responses. **Shipped 2026-08-13** (all four phases).
- `6.0-store-scoped-configuration.md` — Move eight commerce-behavior globals (`auto_capture` + `auto_capture_on_dispatch` → one `capture_method` string; `allow_checkout_on_gateway_error` dropped, not moved — nothing reads it; `track_inventory_levels`, `stock_reservations_enabled`, `track_price_history`, `show_products_without_price`, `address_requires_phone`, `disable_sku_validation`) from `Spree::Config` to `Spree::Store` preferences. Store preference is **authoritative — no runtime fallback** (a fallback chain is what made `default_stock_reservation_ttl_minutes` silently unreachable); upgrade carries values over via `spree:store_settings:backfill_from_config`; globals are deprecated shells until 6.1. Storeless readers (`Address`, the product availability scope) use `Spree::Current.store` with a default fallback. Seven dead settings (`products_per_page`, `storefront_*_path`, …) get shells then deletion. **Capture timing is one vocabulary (2026-08-13):** `Spree::CaptureMethod` = `checkout | on_dispatch | manual` — a Store preference, overridable by a nullable `capture_method` **column** on PaymentMethod (null = inherit; a column, not a preference, since the payment-method preferences blob is per-provider gateway credentials); read `resolved_capture_method`, write `capture_method`; dispatch capture is decided per payment so a `manual` method is never charged by a dispatch; `spree:migrate_capture_methods` carries `auto_capture` over. **Constraints now:** no new `Spree::Config` reads of the movers; no new code against `auto_capture`/`auto_capture_on_dispatch` (deprecated on both models); new behavior flags are born on Store, never global; jobs that validate addresses or query the catalog must set `Spree::Current.store`.
- `6.0-duties-and-custom-fees.md` — Customs duties + shopper-visible custom fees on the shipped typed-`Fee` substrate (**6.0 scope implemented 2026-08-14**; 6.1 provider gem pending): a duty is a `Fee(kind: 'duty')` snapshotting its inputs (`hs_code`/`country_of_origin`/rate/provider) in `metadata` — never a TaxLine, never a new table; classification = three plain columns on `spree_variants` (`hs_code`, `country_of_origin` — **an ISO alpha-2 code, NEVER a country record id, since `spree_countries` is slated for removal**; `customs_description`) editable in both dashboard editors (variant sheet + bulk spreadsheet, sharing `normalize-customs.ts`) and shipped WITH their first consumer (EasyPost customs declaration + shipping-terms option on international labels — EasyPost declares, it never estimates); Store API cart/order serializers gain `fees` + `fee_total` (itemized shopper display is the point); duty estimation rides `Spree.adjusters` (provider gem writes duty fees + its own import-VAT `TaxLine(fee_id:)` rows) — no dedicated duty-provider contract unless a real gem proves the need; duty fees excluded from the default taxable-item set — `Spree::Purchase::Taxation#taxable_items` (shared Cart/Order) is the ONE definition every provider inherits, and it reads **fresh scopes, never the cached associations** (they load empty at record creation, so a Ruby-side `reject` over `fees` silently untaxes every fee — latent bug the duty work surfaced); a provider that does tax duties passes its own item list. 6.0 = plumbing; 6.1 = landed-cost provider gem + `Spree::Market` shipping-terms setting. **Constraints now:** never re-derive duty from the live catalog on an existing order (the metadata snapshot is authoritative); store-serializer money work must not assume fees stay hidden; EasyPost customs data is international-only, never required for domestic; admin cart/order serializers deliberately DROP the inherited `fees` association (admin reads/writes fees through `/orders/:id/fees`, and an admin serializer must never render a store serializer); a new variant attribute must be permitted in THREE places or it is silently dropped on one write path — `PermittedAttributes`, the nested `Admin::Products::VariantsController`, AND the inline `variants: [...]` list on `Admin::ProductsController` (the last is what the dashboard's product Save actually hits; a spec on the nested controller proves nothing about it).
- `6.0-store-scoped-custom-field-definitions.md` — Add `store_id` + persisted `filter_key` to `Spree::MetafieldDefinition` (today global and computed), making uniqueness `(store_id, resource_type, filter_key)` with a DB index. Deferred from the 5.6 custom-field search/sort/filter work (schema change, not patch-safe). **Until then:** `filter_key` is a computed method — no Ransack predicates or `where`/`order` against it; definitions are global; uniqueness rests on a `CONCAT` validation with no index behind it.
- `6.0-opentelemetry.md` — First-class OpenTelemetry support (design finalized 2026-08-12; **phases 1–3 implemented same day** — core notifications + `spree/opentelemetry` gem + telemetry docs page; remaining: fast-follow spans, spree-starter Gemfile mention, collector smoke test): core emits a documented `ActiveSupport::Notifications` surface (NO OpenTelemetry dependency in core) + new optional top-level `spree_opentelemetry` gem (`spree/opentelemetry`) that boots the SDK from standard `OTEL_*` env vars (Saleor-style, no host initializer; `OTEL_SDK_DISABLED` kill switch), installs Rails auto-instrumentation, and translates Spree notifications into spans. Traces only in 6.0 (Ruby metrics/logs SDKs experimental; RED metrics via collector spanmetrics). First cut = commerce core four: workflows (`external_step` marks `external: true` → CLIENT spans; `outcome` payload key set inside the instrumented block), events dispatch, webhook delivery (+ outbound W3C `traceparent`), payment gateway boundary; provider bases/Meilisearch/imports/OIDC fast-follow. **Constraints now:** outbound network calls in workflows are always `external_step`, never `step`; never `rescue StandardError` around workflow execution (`FailureSignal`/`Halted` inherit `Exception`); notification payload keys are public API (additive only) and must be PII-safe; telemetry config is env-var deployment config — never `Spree::Config`, store preferences, or admin UI.
- `6.0-third-party-pricing-inventory.md` — ERP / PIM / DAM integration (**Phases 1–4 + settings UI implemented 2026-08-18/19**; remaining: reference connector gem, developer guides): **Spree is the system of record for what the shopper sees, the external system for what is true** — content, media references, prices and stock levels are SYNCED in; live third-party calls happen only at decision moments (pricing a line, add-to-cart, checkout hold, completion). Shipped: `Spree::ExternalReference` + `Spree::HasExternalReferences` (one polymorphic store-scoped table, unique both ways; `system` is a string key, never an FK; `external:<system>:<id>` member paths and `external_references` on admin writes, create-with-known-key upserts; `Company#external_id` column dropped), `Spree::PricingProvider`/`Spree::InventoryProvider` bases + `Internal` + registries + four Store preferences (`pricing_provider`, `inventory_provider`, `*_failure_policy` — `strict` for pricing, `fallback` for inventory), `Spree::Pricing::PriceResolution` dispatch (cache-keyed, `handles?` fallthrough), `Stock::Quantifier(stock_levels:)` injection, `Spree::Carts::PriceItems`/`CheckAvailability` called as `external_step`s, `line_items.price_source`, `POST /admin/stock_levels/bulk_upsert`, the store-settings provider card + `GET /admin/store/data_sources`, external-URL media (`Spree::Media` `external_image` + `external_media_url`, served through `hosted_still_url`; `external_video_url` stays separate — a parsed provider embed link, not an address for bytes). **Constraints now:** no new `external_id` columns (include `Spree::HasExternalReferences`); never call an external system from `Variant#in_stock?`/`purchasable?`, `ProductScopes` or a serializer — the inventory READ path is local; provider calls are `external_step`s through `Carts::PriceItems`/`CheckAvailability`, and no new call sites of `LineItem#recalculate_price`/`update_price`; a pricing stand-in line item must be built detached, never through `cart.line_items.new` (the line-item finder finds it and doubles quantities); connectors never write `count_on_hand` directly — go through the bulk upsert or `stock_location.adjust`; a feed value that is not a number is refused, never coerced (`"12,50".to_d` is a hundredfold overcharge).

Multi-version plans (some phases shipped, some pending):

- `6.0-6.1-split-adjustments.md` — Replace polymorphic Adjustment with TaxLine, Discount, Fee. **6.0 implementation fully shipped to main** (typed tables + models, `Spree::Adjusters::*` winner-only promotion adjuster, `Spree.tax_provider` seam, admin `/orders/:id/{tax_lines,discounts,fees}` API + SDK + dashboard cards, `spree:migrate_adjustments_to_typed_rows` in the upgrade manifest; legacy `Adjustment`/`AdjustmentSource` deleted). v6 developer docs shipped (`docs/v6/developer/` taxes-discounts-fees + promotions + custom-promotion). Remaining: 6.1 drops `spree_adjustments` + deprecated shells and adds `Promotion#combines_with` stacking.
- `5.4-store-api-naming-standardization.md` — Standardize API naming against industry (address fields, discounts, customer_note, label, brand/last4, etc.). 5.4 model/API aliases shipped; 6.0 column/table renames pending.
- `5.4-6.0-eu-legal-compliance.md` — GDPR (data export/anonymization, consent timestamps), Omnibus (PriceHistory, lowest-in-30-days), Consumer Rights (withdrawal period). 5.4 PriceHistory + `prior_price` shipped; GDPR endpoints + withdrawal period still pending.
- `5.4-6.0-custom-fields-rename.md` — Rename Metafields → Custom Fields. 5.4 API bridge + 5.5 `Spree::CustomField`/`CustomFieldDefinition` constant aliases shipped; 6.0 model/table rename pending.
- `5.4-6.0-product-media-system.md` — Product-level media gallery. 5.5 data model (spree_variant_media, media_type, focal_point, external_video_url) shipped; admin UIs in progress; 6.0 cleanup pending.
- `5.5-6.0-order-cancellation-and-approval.md` — First-class `OrderCancellation` + `OrderApproval` models. 5.5 models + migrations shipped; 6.0 drops denormalized columns.
- `5.5-6.0-display-on-to-boolean.md` — Collapse `display_on` tri-state to a single `storefront_visible` boolean. 5.5 bridge (`storefront_visible` accessor + Ransacker on `Spree::DisplayOn`) shipped; 6.0 schema rename pending.
- `6.0-order-routing.md` — Two-tier extension: pluggable `Spree::OrderRouting::Strategy::Base` + STI subclasses of `Spree::OrderRoutingRule`. Phase 1 (5.5) shipped: `Channel`, `OrderRoutingRule`, strategy base + Rules + Reducer + Legacy, `preferred_stock_location_id` + `channel_id` on Order. Phase 2+ (6.0) layers Catalog/Company on top via `6.0-channels-catalogs-b2b.md`.
- `6.0-channels-catalogs-b2b.md` — Channel + ProductPublication (replaces StoreProduct) + single-owner Product (`belongs_to :store`) + Publishing card (legacy admin + SPA) + `Channel#default` boolean shipped in 5.5; gated storefront access shipped in 5.6. The Catalog + Company phase is **superseded by `6.0-b2b-companies-and-catalogs.md`** (implemented 2026-08-25 — B2B pulled back into 6.0 as a headline). Multi-store catalogs (historic `Product has_many :stores`) move to the `spree_multi_store` extension.
- `5.6-6.0-single-store-promotions-payment-methods.md` — Migrate `Spree::Promotion` + `Spree::PaymentMethod` from multi-store (`has_many :stores` via `spree_promotions_stores` / `spree_payment_methods_stores` join tables) to single-owner `belongs_to :store`, mirroring the 5.5 single-owner Product migration. 5.6 (implemented): `store_id` FK + required-store presence via `Spree::SingleStoreResource`, backfill rake task (loud per-record deprecation on shared records), shared `LegacyMultiStoreSupport` deprecation bridge, deletes the `ResourceController` `store_ids=` seam, deprecates `StoreScopedResource`; multi-store sharing moves to the `spree_multi_store` extension (join tables left intact). 6.0 cleanup: enforce `null: false`, drop join tables + bridges. Paired with `6.0-channels-catalogs-b2b.md`.
- `5.6-project-layout-and-dashboard.md` — React Dashboard Developer Preview packaging + `backend/` → `api/` project layout. Implemented: `<Dashboard />` shell export from `@spree/dashboard` (source-only, relative imports only), monorepo-canonical `packages/dashboard-starter` thin host (embedded standalone into the `@spree/cli` tarball at build time via `scripts/sync-dashboard-starter.mjs` — no template repo; create-spree-app delegates to the project-local `spree add dashboard`), `spree add dashboard` + create-spree-app dashboard phase (opt-in via `--react-dashboard` while WIP — not prompted; env carries only `VITE_API_PROXY_TARGET` — never secret keys, and never `VITE_SPREE_API_URL`, which would flip the SDK to absolute cross-origin URLs and break dev on CORS), npm release job for `@spree/dashboard{,-ui,-core}` (0.x → `next` tag). Pending: layout rename + `detectApiDir` dual-layout CLI, `spree upgrade layout`; optional public template repo at 6.0 GA.
- `5.6-dashboard-typed-plugin-routes.md` — Plugin file routes compiled into the host's TanStack route tree: `spree.dashboard.routes` marker + virtual-route-config composition in `@spree/dashboard/vite`, `createDashboardRouter` + `<Dashboard router>` ownership inversion, typed cast-free links, cross-package collision pre-flight with package-named errors. Runtime route registry stays for dynamic/in-app cases (catch-all is lowest priority). Implemented; published-tarball spike passed.

Pending design work (drafts, no implementation yet):

- `6.0-6.1-b2b-payment-terms.md` — Deposit-style payment terms + bank references (design finalized 2026-08-30; **collect-first OSS, ship-first Enterprise** — Net terms/credit/invoicing/dunning stay Enterprise roadmap): ONE frozen **`payment_terms` jsonb snapshot** on cart/order (`{kind: prepaid|deposit, deposit_percentage, balance_due_label, source}`) resolved quote/order override → company `payment_term_id` (→ `Spree::PaymentTerm` store-scoped presets, `kind` class_attribute Enterprise extends with `net`) → freight-method deposit prefs (demoted to default source — wholesale plan amended) → none; `Cart#amount_due_at_checkout` reads the snapshot; the **payment schedule** (due-now/deposit-state/balance+label) is derived on read — `Orders::UpdateStatuses` untouched; balance-due moment is a LABEL, real due dates are Enterprise. 6.1: `PaymentMethod::BankTransfer` (public-preference account details), stored generated **`reference` on every payment** (structured RF-style, unique, ransackable — the reconciliation identifier), storefront pay-balance route (`POST /store/orders/:id/payments`, capped by `max_amount`). 6.0 fixes: derived `R1001-P1` number removed from ransack whitelist + Stripe `find_by(number:)` corrected (NULL column). **Constraints now:** terms read from the snapshot, never re-resolved post-placement; nothing durable keys on derived payment numbers; no net-terms/credit/due-date machinery in OSS; payment-collecting surfaces respect `amount_due_at_checkout` + `max_amount`.
- `6.1-order-stages.md` — Merchant-composed order stages (design finalized 2026-08-30; **stages are data, statuses stay code** — the doctrine ruling): store-scoped `Spree::OrderStage` rows (acts_as_list, `customer_visible` flag, optional **auto-enter event binding** from the `Spree.order_stage_events` registry — event-driven labeling, never gating) composed visually in a dashboard settings page; `spree_orders.order_stage_id` (nullable) + `expected_ready_on` (order-level merchant promise — distinct from variant `preorder_ships_at` supply fact and fulfillment `estimated_delivery_at` carrier truth); `Orders::SetStage` is the single writer (manual select or binding subscriber), publishes `order.stage_changed` (automation rides events); store serializer shows the stage only when visible + a progress indicator over the visible ordered subset. **No transition graph ever; stages carry zero commerce semantics** — nothing in checkout/payments/stock/fulfillment may branch on `order_stage_id`; a needed GATE is a code status/workflow validation, never a stage; no per-store vocabularies on `has_status` models (statuses are process-global code); `Order` deliberately NOT migrated to `has_status`. No platform offers composed stages (nearest: display labels pinned to fixed states, or code-config state machines) — OSS first.
- `6.1-b2b-order-documents.md` — Order Documents area + logistics prints (design finalized 2026-08-30): `Spree::OrderDocument` (order-nested uploads, private storage + spoofing protection, per-document `customer_visible` default false, buyer uploads allowed, `po_document` keeps its dedicated semantic slot) + two client-side HTML prints extending the shipped packing-slip pattern — carton/pallet/CBM **packing list** off the frozen freight summary, **payment-instructions sheet** off the terms schedule + bank reference. **No invoice vocabulary in OSS** (no model/number/document named invoice, no PDF stack — numbered proforma/commercial docs are Enterprise invoicing); order-facing files go through `OrderDocument` or a dedicated semantic slot, never loose attachments; prints render `po_number` + payment reference when present.
- `6.1-order-change-substrate.md` — `Spree::OrderChange` + `Spree::OrderChangeAction`: one preview-then-apply substrate behind every post-placement mutation (admin order edits, returns, exchanges, claims — **draft orders excluded**: Phase 5 superseded 2026-08-30, the substrate is strictly post-placement; drafts are directly mutable with no balance to settle, and edit screens may share components but only placed orders create OrderChange rows), replacing four per-domain draft models with one `begin → request → confirm → cancel` lifecycle. Actions are typed `kind` + concrete FKs (never polymorphic); **preview is computed in memory and never persisted**; confirm is a workflow with the balance settlement as an `external_step`. Deliberately 6.1 — new schema + new extension API, and 6.0 already carries the Cart/Order split, typed adjustments and the returns rework. **Resolved 2026-08-10:** a change set belongs to one `Order`, never an `OrderGroup` (multi-seller edits = N change sets, each settling against its own order); a pending change set does **not** hold stock (`add_item` takes stock at confirm — reservations are checkout-scoped and would have no expiry trigger here). Phase 3 replaces the **6.0 order edit screen** (`/orders/$orderId/edit`) — quantities as inputs, `x` marks a row removed, Save applies the batch (**reshaped 2026-08-11**, reversing the original immediate-write rule); Phase 3 adds `begin`/preview/`confirm` behind the Save/Discard it already has. 6.0 constraints: don't **persist** a draft/preview model (transient React form state is fine and is the shape the substrate wants), don't compute projected totals client-side to fake a preview, expose post-placement money math through a service returning a value object, and keep line-item mutation on the edit screen rather than the fulfillment card. Known gap: the batch save is not atomic (no bulk endpoint; Phase 3's `Confirm` fixes it in one transaction). **Applier rulings (2026-08-30):** appliers never derive unit prices (a `price_source: 'manual'` line comes through an amendment untouched); a post-placement price change is its own future action kind (`update_item_price`), never a discount abused as one.
- `6.0-payment-method-rules.md` — `Spree::PaymentMethodRule` STI on PaymentMethod (Channel / Market / OrderTotal / CustomerGroup rules), mirroring the PromotionRule/PriceRule/OrderRoutingRule pattern. Enforced solely through `Order#collect_frontend_payment_methods` (listing + `Payments::Create` + payment sessions all flow through it); admin/backoffice bypasses; no rules = available everywhere. Dashboard-only management (nested Admin API CRUD + `/payment_method_rules/types` discovery). Supersedes the "no distribution concept" rationale in `5.6-6.0-single-store-promotions-payment-methods.md`; per-channel provider credentials (multiple Stripe accounts, multi-entity setups) explicitly deferred for grooming — see decisions.md 2026-07-23.
- `6.0-channel-delivery.md` — **Implemented in PR #14404 (2026-08-09).** Optional Channel→StockLocations allowlist (`spree_channel_stock_locations`, empty = all): constrains which fulfillment origins serve a channel's traffic, enforced origin-side (Coordinator allocation + pickup discovery intersect `Channel#serves_location?`) — never on profiles/groups (channel constraint composes from outside; Medusa-shaped transitive delivery). `preferred_stock_location_id` must be a served location. **Per-channel rates** are a separate axis: `DeliveryMethodRules::ChannelRule` (STI, beside ItemTotal/Weight/ExcludedProducts) gates which methods a channel is *offered* from origins it already reaches — origins decide whether a channel can be served, rules decide what it sees.
- `6.0-channel-markets.md` — Optional Channel→Markets allowlist (`spree_channel_markets` join, empty = all markets). Enforced in market resolution (`set_market_from_country` + channel-aware `Spree::Current.market` fallback), channel-filtered Store API `/store/markets`, and order-level `market must be served by channel` validation. Composes with `MarketRule` from the payment-method-rules plan.
- `5.6-admin-spa-csv-import.md` — Universal dashboard CSV import over the existing `Spree::Import` pipeline (implemented). Admin API v3 surface (create via direct-upload signed blob, `complete_mapping`, `retry_failed_rows`, nested failed-rows index, write-scope gating), `client.imports` SDK resource, dashboard-core `ImportButton` (per-context `<Can>` gating, upload Sheet) + full-window wizard dialog driven by an `?import=` search param, with history under `/settings/imports` (new `audit` settings-nav group). Status via API polling — explicitly no ActionCable/Turbo Streams in the SPA; legacy per-row live feed replaced by polled counters + paginated failed-rows table.
- `5.5-6.0-resource-translations-api.md` — Admin API v3 translation management + React dashboard for all `Spree.translatable_resources`. Hybrid: embedded `translations` object on resource update + generic dedicated `…/:id/translations` endpoint (one registry-driven controller), self-describing field discovery, advisory server-side staleness. Canonical `{ locale → { field → value } }` shape (consistent with metafield-translations). Cross-record bulk = CSV import/export generalized across the registry (NOT a JSON bulk endpoint — no competitor ships one). Phase 1 (5.5) API; Phase 2 (6.0) coverage read + CSV generalization + staleness + centralized SPA page; Phase 3 folds in metafields.
- `5.4-centralized-translations-admin.md` — Centralized Translations admin page under Products, overview grid + bulk CSV import/export
- `5.4-metafield-translations.md` — Translate MetafieldDefinition names + Metafield text values (ShortText, LongText, RichText) via Mobility translation tables
- `5.5-admin-api-cli.md` — `spree api` command group in `@spree/cli` (gh-api-style generic verbs + schema introspection + layered auth, CLI-first ahead of MCP servers; core patch: `SCOPES` on `spree:cli:create_api_key`, promotions scopes)
- `6.1-exchange-rates.md` — `Spree::ExchangeRate` + `ExchangeRateProvider` (ECB feed as the credential-free default, registry copied from `tax_providers`/`delivery_rate_providers`, keyed providers via `Spree::Integration`). **Rates fill fields, they never price anything** — a merchant gets editable suggestions for the other currencies and what persists is a plain number they own; Spree's "one explicit amount per currency, no FX" stance is unchanged. Never at charge time: EU VAT Directive Art. 91 pins the rate to the instant VAT becomes chargeable, so a commission invoice's VAT figure must be frozen with its rate/date/source or the platform cannot reproduce its own filed documents (Shopify converts at capture and is the wrong pattern here; Vendure/Medusa/Saleor never convert in core). Rates are stored historically and looked up **most-recent-on-or-before**, never exact-date (the ECB skips weekends); cross-currency derives through the base per Art. 91, never stored as a third row; rate precision is NOT money's `decimal(_,2)`. **Constraints now:** never set `Money.default_bank` or call `exchange_to` (the empty rate store raising `UnknownRate` is correct); new money configuration is born per currency, never one amount + a currency column; no conversion endpoint on any API. Also records two live promotion bugs found while researching it — `Calculator::FlatRate` silently discounts **zero** on a currency mismatch, and `Promotion::Rules::ItemTotal` stores a bare threshold with no currency — both independent of this feature.

Shipped plans:

- `6.0-b2b-companies-and-catalogs.md` — B2B companies as a **multi-level organization tree** + Catalogs pulled into 6.0 (**implemented 2026-08-25**; replaced the unreleased Company→CompanyLocation→CompanyContact prototype outright — migrations rewritten in place, no bridges). One `spree_companies` table: self-referential `parent_id`, `kind` = `company` (legal entity) | `division`, depth capped at `MAX_DEPTH` (5), roots must be `company`; **`#legal_entity` (nearest self-or-ancestor company node) is the single tax anchor** — TaxIdentifier/TaxExemptionCertificate refuse division owners, and purchases read `company_legal_entity`, never the node. `CompanyAddress` (owned rows, labeled, one default per kind via Channel-style demotion + partial index), `CompanyMembership` (always customer-backed; standing = node + subtree, checked via `Customer#standing_for?`/`company_standing(store:)` — never node equality), `CompanyInvitation` (plaintext token, 30-day expiry, pending-scoped uniqueness; mail in `spree/emails`, acceptance via `CompanyInvitations::Accept` running `Customers::Create`; both member-adding surfaces converge on `Companies::AddMember` by email). Carts/orders carry `company_id` (any node; cart-side standing validation, sole-membership resolution in `resolved_company`, frozen at completion). **Catalogs:** `Catalog` (assortment + optional PriceList) + `CatalogProduct` (membership only — **no position**: a catalog decides what a buyer sees, never the order they see it in; category/collection membership stays positioned) + polymorphic `CatalogAssignment` (CustomerGroup|Company — buyer audiences only, company assignments cover the subtree; narrowed 2026-08-28 from the original four: Channel/Market were write-only — a channel's catalog is `spree_channels.default_catalog_id`, a market catalog returns only with a designed regional-assortment reader); visibility = `Products::ForContext` (union of effective catalogs, wired into the store products listing), pricing = catalog price lists nearest-node-first in `Pricing::Resolver` (catalog-bound lists excluded from generic rule matching — a rule-less list must not leak to everyone). Store API self-service (`/store/account/companies`, `/store/companies/*`, unauthenticated invitation lookup/accept, writable cart `company_id`) authorizes by **standing + `Storefront::AccessPolicy`** (company branch answers yes for any member — OSS has no company roles; Enterprise narrows via the policy class + checkout hooks). Dashboard: lazy tree list, node page (sub-units/members+invitations/address book; tax cards hidden on divisions), catalogs pages; slots renamed `company_membership.*`, `company.form_*` only. **Constraints:** never reference the deleted location/contact models; no governance fields on OSS models; `kind` stays the fixed two (divergence = STI, never a second table); catalog/company lookups store-scoped including incidental ids. **Amended 2026-08-30 (one-question-per-entity doctrine — decisions.md):** the Catalog is the **commercial agreement** — it grows commercial terms (catalog-level `minimum_order_quantity`/`order_multiple` columns + per-variant override rows + per-currency order minimums, owned by `6.0-b2b-quantity-rules.md`); the list binding **inverts** to `spree_price_lists.catalog_id` (a list is standalone or owned by ONE catalog; generic rule matching skips owned lists by FK — the shipped active-catalogs-only derived set leaked a deactivated catalog's rule-less list to the whole store); `PriceRules::CustomerGroupRule`/`UserRule` grandfathered alongside `PriceRules::ChannelRule` (all kept working, hidden from the picker, nothing new builds on them — forward path is catalog assignment, and for a channel its default catalog); dashboard goes catalog-first with one-go setup (inline `price_list` payload on catalog create/update, products-with-prices view). Implementation extracted to `6.0-catalog-agreement-rework.md` (Draft).
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
| --- | --- |
| `spree/core` | Ruby gem — models, services, business logic (`spree_core`) |
| `spree/api` | Ruby gem — Store & Admin REST APIs (`spree_api`) |
| `spree/emails` | Ruby gem — transactional emails (optional). Rebuilt + modernized in 5.6. The default email stack for installations without a storefront app (e.g. mobile apps); headless storefronts may instead own consumer emails via webhooks. |
| `spree/providers/easypost` | Ruby gem (`spree_easypost`, optional) — reference `DeliveryRateProvider` + `FulfillmentProvider`: live EasyPost rates, label purchase/refund, credentials via `SpreeEasyPost::Integration`. Provider gems live under `spree/providers/` (stripe/adyen/avalara land there too); gem names stay flat. |
| `spree/providers/meilisearch` | Ruby gem (`spree_meilisearch`, optional) — `SpreeMeilisearch::SearchProvider` + `SpreeMeilisearch::ProductPresenter`: typo-tolerant product search, disjunctive facets and merchant-ordered grouping pages. Extracted from core in 6.0; credentials come from `MEILISEARCH_URL`/`MEILISEARCH_API_KEY` (index is installation-wide infrastructure, not a per-store `Integration`). |
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
| `storefront/` | Next.js storefront cloned from `spree/storefront` branch `6-0-dev` (.gitignored, provisioned per worktree; keeps its `.git` — commit and push from inside it) |

## Development Server (worktrees)

Development happens in **git worktrees** — every worktree is a self-contained native dev environment, no Docker: its own gitignored `server/` clone of spree-starter (monorepo gems loaded as path gems via `SPREE_PATH`), its own database on the shared Homebrew Postgres (:5432, copied in ~2 s from the seeded `spree_worktree_template`), and stable per-branch https URLs via [portless](https://github.com/vercel-labs/portless). Worktrees are managed with [worktrunk](https://worktrunk.dev) (`wt`): creating one runs `scripts/worktree/setup.sh` automatically (see `.config/wt.toml`), removing one drops its databases. The main checkout is for integration (merges, template rebuilds), not for running servers.

```bash
wt switch -c feature-x       # create worktree + provisioned environment (~20 s)
pnpm wt:dev                  # Rails → https://feature-x.spree.localhost  (/up, /api/v3, /jobs; jobs run inside Puma via Solid Queue)
pnpm wt:dashboard            # admin UI → https://admin.feature-x.spree.localhost
pnpm wt:seller               # seller panel → https://sellers.feature-x.spree.localhost
pnpm wt:storefront           # Next.js storefront → https://store.feature-x.spree.localhost
pnpm wt:e2e [spec...]        # Playwright on this worktree's own port block
pnpm wt:template             # rebuild the template DB after schema-changing pulls
wt merge main                # ship + clean up (worktree, branch and databases all removed)
wt remove                    # abandon instead of shipping
```

Admin login: `spree@example.com` / `spree123`. The dev scripts run in the foreground and stream logs; `server/log/development.log` has the Rails log if the server runs detached. Start servers only in worktrees you're actively looking at — rspec/vitest/tsc need no servers.

**Storefront (`pnpm wt:storefront`).** The Next.js storefront is a separate repo (`spree/storefront`) cloned per worktree into a gitignored `storefront/`, on its **`6-0-dev`** branch — `main` stays on the released Store API for people forking or deploying it. Unlike `server/`, the clone keeps its `.git`: commit and push storefront work from inside it, and push before `wt remove`, which deletes the clone with the worktree.

It is deliberately **not** a member of this pnpm workspace — one lockfile and one set of global overrides cannot serve both Next 16 and the dashboard's Vite tree. It instead points `@spree/sdk` at this worktree's `packages/sdk` through its own `.pnpmfile.cjs`, which rewrites the dependency only when `SPREE_SDK_PATH` is set (the JavaScript twin of `SPREE_PATH`), so a standalone clone still installs the published SDK. The rewrite uses `file:` and not `link:`, because the storefront pins module resolution to its own directory (`turbopack.root`, `output: "standalone"`) and lists the SDK in `transpilePackages` — a symlink pointing outside the project fails to resolve, and every `@spree/sdk` import breaks. Two consequences: the storefront's `pnpm-lock.yaml` will show a local path — never commit it — and because the SDK is **copied**, picking up a change to it means rebuilding and reinstalling, which is exactly what re-running `pnpm wt:storefront` does.

`storefront/.env.local` is regenerated on every boot with this worktree's API URL and the seeded publishable keys (read straight from Postgres — publishable tokens are plaintext), so a reseeded database can't leave a stale key behind. Anything you add below the marker line is preserved.

One-time machine setup: Homebrew `postgresql@18` running on :5432 (with a `postgres` superuser role), `mailpit` (`brew services start mailpit` — one instance serves every worktree), Ruby per `server/.ruby-version` (mise or rbenv), Node ≥ 24 with `npm i -g portless` (start the proxy once with `portless proxy start`, accepting sudo for :443), worktrunk, then `pnpm wt:template`.

| What changed | What to run (inside the worktree) |
| --- | --- |
| Ruby code in `spree/*` gems | Nothing — path gems, reloads on next request |
| New migration in a gem | `cd server && bin/rails spree:install:migrations db:migrate`; then `pnpm wt:template` once so future worktrees inherit it |
| Deleted and re-cloned `server/` | `pnpm wt:template` — the 6.0 migrations still ship from the gems, so re-cloning renumbers them and the old template no longer matches. `wt:setup` refuses to provision from a mismatched template and rebuilds it automatically when it re-created `server/` itself |
| Gem dependencies | `cd server && bundle install` (the gem home is shared across worktrees, so this is fast) |
| Need sample data (products + images) | `cd server && bin/rails spree:load_sample_data` — per worktree, on demand; takes minutes and hits the network |
| Rails console / database | `cd server && bin/rails console`; the DB is `spree_dev_<branch>` on `localhost:5432` |
| E2E prerequisites | Once per worktree: `cd spree/api && bundle install && bundle exec rake test_app` (then `pnpm wt:e2e`) |
| Read an email the app sent | Mailpit catches everything: <http://localhost:8025>. `brew install mailpit && brew services start mailpit` if it is not running — without it the starter falls back to a delivery method that does not exist and every send raises |
| Store API serializers or SDK code, and the storefront is running | Re-run `pnpm wt:storefront` — it rebuilds the SDK and copies it in. Run the [type generation pipeline](#type-generation-pipeline) first if you changed serializers |
| Meilisearch search provider | Optional: `brew install meilisearch`, run it, set `MEILISEARCH_URL` in `server/.env`, `bin/rails spree:search:reindex` |
| Hosted dashboard at `/dashboard` (single-node test) | `pnpm server:dashboard` to build `packages/dashboard-starter/dist`, set `SPREE_DASHBOARD_DIST_PATH=<monorepo>/packages/dashboard-starter/dist` in `server/.env` |
| Hosted seller panel at `/sellers` (single-node test) | `pnpm server:seller` to build `packages/seller-dashboard-starter/dist`, set `SPREE_SELLER_PANEL_DIST_PATH=<monorepo>/packages/seller-dashboard-starter/dist` in `server/.env` |
| Broken beyond repair | `wt remove` and recreate — or `dropdb spree_dev_<branch>`, delete `server/`, re-run `pnpm wt:setup` |

**The legacy Docker compose flow (`pnpm server:setup` / `server:dev` / `server:stop` etc.) is deprecated — never use it.** It exists only for spree-starter parity; it fights the worktree stack for ports and its teardown scripts wipe shared state.

---

## General rules

- ONLY comment complex or non-obvious methods/code, do not comment every method or class, DON'T create comments noise
- DON'T comment code removal, just delete it
- DON'T comment obvious and native to Rails framework methods, associations, validations
- DON'T comment on shapes, serializers, types
- Commit message body: max 3-4 sentences, DON'T include implementation detail, focus on the "what" and "why", not the "how"
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
- No state machines. Spree has none since 6.0 and `state_machines-activerecord` is not a dependency — declare statuses with `has_status` (column always `status`) and move records between them with Workflows (see docs/plans/6.0-normalize-state-to-status.md)
- NEVER cast IDs to integer — always treat as strings (UUID support)
- Uniqueness validations: ALWAYS use `scope: spree_base_uniqueness_scope`, should be also enforced by database index
- If needed use paranoia gem for soft delete support (via `acts_as_paranoid`)
- For configuration / options always use [Model Preferences](docs/developer/customization/model-preferences.mdx)
- NEVER hardcode table names, always use `Model.table_name` in models, queries, scopes, etc.
- ALWAYS use Arel, scopes and ActiveRecord helpers to build queries, only use raw SQL if cannot use Arel
- ALWAYS use normalizes for normalization of attributes, DON'T use custom before_action callbacks
- ALWAYS use insert_all/upsert_all when creating records in bulk, this relies on proper database uniqueness indexes. Special treatment for MySQL is needed though
- ALWAYS put callbacks in private group
- ALWAYS use existing vocabulary and naming patterns, avoid slang terms

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
class CreateSpreeMetafields < ActiveRecord::Migration[8.1]
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

**A resource written through a workflow declares it, never re-implements the action.** Override `create_workflow` / `update_workflow` to return the workflow, and the inherited `create`/`update` keep their authorization, their result handling and their rendering — hand-writing those actions is how a controller silently loses the record-level `authorize_resource!` the base class does. Override `create_workflow_arguments` / `update_workflow_arguments` when the workflow's keywords differ from the defaults (`store:`/`attributes:` and `<resource>:`/`attributes:`).

`build_resource` builds through the owner's association — `current_store.products`, or a nested resource's parent — so a new record carries its tenancy from where it was built rather than from an attribute assigned afterwards. A model the store has no association for falls back to the class. When a `create_workflow` is declared the record is left bare, since the workflow assigns the payload and the authorization check reads the record's owner rather than its attributes.

#### Flat request/response structure

API v3 uses flat params — no nested Rails-style wrapping. Declare a controller's writable attributes by overriding **`resource_permitted_attributes`** (a plain list). The base `permitted_attributes` appends extension-contributed attributes to it, and `permitted_params` permits and normalizes the result. `Spree::PermittedAttributes` and its model-name inference are **removed in 6.0** — a controller that declares neither `resource_permitted_attributes` nor `permitted_params` raises `NotImplementedError` on its first write.

Extensions add writable attributes to a core resource from an initializer, appending to the model's `additional_permitted_attributes` (a `class_attribute` on `Spree::Base`, default `[]`): `Spree::Product.additional_permitted_attributes += [:brand_id]`. Always `+=`, never `=` — assigning replaces what another extension added. Core STI subclasses set theirs with `self.additional_permitted_attributes = [...]` in the class body. Three rules that matter:

- **Override `resource_permitted_attributes`, never `permitted_attributes`** — the latter is where the extension union happens, so overriding it silently drops extension attributes.
- **A controller that overrides `permitted_params` outright opts out of the union.** If it needs both, splat `model_additional_permitted_attributes` into its own `params.permit`.
- **`normalize_params` is not free.** It recurses into nested hashes decoding anything matching the prefixed-ID shape, so a controller carrying opaque provider values (gateway `preferences`, merchant `metadata`) must NOT normalize — a Stripe `we_1MqJ8b...` id would be decoded to an integer. `Admin::PaymentMethodsController` is the worked example. Conversely, a controller that *does* normalize receives already-decoded primary keys, so read raw `params` when you need a prefix-checked `find_by_prefix_id!`.

Prefer Custom Fields for merchant-managed data; the hook is for extensions adding real columns.

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
- **No internal state** — never expose `cost_price`, internal status flags, soft-delete columns, audit logs, internal notes, `metadata`, or admin-only relations (sellers, fulfillment providers)

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

### Time zones

- Parsing or formatting a date **for a store** uses that store's zone, never
  the server's: `Time.find_zone(store.preferred_timezone)` (which answers `nil`
  for a zone it does not know, so fall back with `|| Time.zone`), or
  `.in_time_zone(store.preferred_timezone)` on an existing time. A merchant who
  types `2026-01-01` means midnight where they trade — read in the server's
  zone that deadline moves by hours for every store that is not on it.
  Precedents: `Spree::CollectionRules::AvailableOn`, `Spree::Report`,
  `Spree::PriceList`.
- Stamping *now* (`Time.current`) needs no zone — it is an instant, stored as
  UTC, and reading it back in a store's zone is the display layer's job.
- Never `Time.zone.parse` operator input where a fixed instant is meant:
  `parse` fills in whatever the value omits, so `"09:00"` becomes today at nine
  and the stored threshold moves every midnight. Use `iso8601`, which refuses
  anything that is not a complete date.

### Documentation

- Re-generate OpenAPI spec after API changes: `bundle exec rake rswag:specs:swaggerize`
- OpenAPI spec: `docs/api-reference/store.yaml` (generated from `spree/api/spec/integration`)
- Update developer docs in `docs/developer/` when relevant
- DO NOT edit the OpenAPI specs manually, it is generated from the integration tests. If you need to change the spec, change the integration tests instead and run swaggerize to regenerate the spec.
- Regeneration is **deterministic**: the clock is frozen and every random name, email and token is seeded, so re-running swaggerize without changing the API produces a byte-identical file and an empty diff. A diff in `docs/api-reference/*.yaml` therefore means the API response actually changed — review it. The pinning lives in `spree/api/spec/support/deterministic_openapi.rb` and applies only under `OPENAPI=true` (set by the rake task), so normal spec runs keep their random data and real clock.
- Because the clock is frozen, a factory whose record must already be in effect cannot rely on `Time.current` as its start: `starts_at < Time.current` is false when the two are the same instant. Give such factories a start slightly in the past (see the `:promotion` factory).

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

The split lets plugin authors register UI via `defineDashboardPlugin` from `@spree/dashboard-core/plugin`, build new pages with `@spree/dashboard-ui` primitives, and reuse the same providers/hooks. It also lets app developers compose custom dashboards (e.g. seller panels) from the same packages.

**Running the admin UI locally** (from a worktree — see "Development Server" above):

```bash
# 1. Boot this worktree's Spree backend (one terminal)
pnpm wt:dev             # foreground; streams logs — https://<branch>.spree.localhost

# 2. Boot the admin (separate terminal)
pnpm wt:dashboard       # https://admin.<branch>.spree.localhost (proxies /api/* to this worktree's Rails)

# 3. Boot the marketplace seller panel (third terminal, optional)
pnpm wt:seller          # https://sellers.<branch>.spree.localhost
#    Seed a seller to sign in as:
#    cd server && bin/rails spree:sellers:sample_data   → seller@example.com / spree123
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

When displaying amount or percentage fields please always use `<InputGroup>` with a suffix/prefix, showing `%` or currency signs. Also numeric fields should use `number` input type.

**Base UI `<Popover>` is unreliable inside a `<Sheet>`'s portal tree.** Symptom: the trigger gets `aria-expanded="true"` and `data-popup-open=""` on click, but no `[data-slot="popover-content"]` ever appears in the DOM. Happens in deeply-nested portal trees (Sheet → SortableContext → TableRow → Popover). Fix: render the panel inline with `absolute top-full left-0 z-50` + a `document.pointerdown` click-outside listener + Escape-to-close. A portal is only needed to escape an `overflow: hidden` ancestor; for table cells and form fields, inline is fine. Reference: `components/spree/color-picker.tsx`, plus `<StoreDatePicker inline>` above.

`Currency` should be always rendered as a dropdown using `currency-select.tsx` component, this also applies to Preferences fields representing currency
`Country` and `Countries` fields should always use `copuntry-combobox.tsx` component, this also applies to preferences fields representing a single country or multiple choices

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
- Prefer `build` over `create` for speed, use `create_list` for creating multiple records
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
