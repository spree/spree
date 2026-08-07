## 2026-08-06: A product type's `required` custom field is advisory — no server-side enforcement

Reverses the "enforced at activation" position taken earlier the same day
in `6.0-product-types.md`. The flag stays on
`ProductTypeCustomFieldDefinition`, ships in the Admin API, is editable
in the type editor, and renders as a marker on the product form — but no
model validation rejects a blank value.

**Why.** Spree writes a product and its custom fields in *two* steps:
the CSV importer saves at `product_variant.rb:88` and attaches
metafields at `:93`, and API clients can do the same (a metafield needs
a persisted parent, so `custom_fields=` stashes values until
`after_save`). Any save-time rule fights that. Three triggers were tried
and each failed: activation-only left a product created `active`
permanently non-compliant, since status never changes again; excluding
creation had the same hole; including creation broke the sample-data
import twice and needed a staging shim inside the importer to work
around the model's own rule.

**Competitor check.** Shopify has no required flag on metafield
definitions at all — validations cover length/range/regex only. Medusa
and Vendure have no type-driven required concept. Only Saleor enforces
(`valueRequired`), and it can because attributes exist *solely* through
the product type and ride the product mutation atomically. Neither holds
in Spree, where any definition can attach to any product independently
of a type. Adopting the Shopify position deletes the most fragile code
in the feature.

**Constraint going forward:** never add a model validation for this. A
dashboard-side nudge on the activation action is acceptable and
reversible; a server rule is not.


## 2026-08-06: ProductType is a creation-time template, not a live sync; type changes are allowed; no Store API exposure

Competitor review (Saleor / Shopify / Medusa / Vendure) reversed the
2026-07-27 "live template" and hard-immutability decisions in
`6.0-product-types.md` before the unshipped Phase 2 built them. Saleor
is the only platform with live propagation, and only because its
attributes have no existence outside the type; Shopify — the largest
merchant base on this problem — made category changes affect nothing
retroactively. The settled semantics:

- **Two regimes by data nature.** Custom-field form generation,
  required-field validation, and `fulfillment_types` are **live by
  reference** (read from the type at use time — no sync needed to be
  "live"). Option types and categories are **seeded additively at
  attach** (creation or later assignment); editing a type never mutates
  existing products. No propagation callbacks, no locked option types,
  no provenance tracking.
- **One explicit bulk path:** `ProductTypes::ApplyToProducts` —
  additive-only, idempotent, previewed with `products_count`, run as a
  background job, shipping in 6.0 Phase 2. A deliberate bulk edit the
  merchant asks for by name, never a side effect of editing a type.
- **Required fields validate at activation only** — never on ordinary
  saves of an already-active product, otherwise adding a required
  definition to a type bricks every active product of that type on next
  save (Shopify precedent: definition validations gate new writes only).
- **A product's type is changeable**: explicit per-product detach and
  reassign, both non-destructive (nothing deleted; custom-field values
  survive as unstructured values; the new type seeds additively and its
  required fields are checked at next activation). The immutability
  guard was never shipped and will not be. Deleting a type in use stays
  `restrict_with_error`.
- **ProductType is back-office vocabulary — no Store API surface at
  all** (no endpoint, no expand, no filter). Storefronts see categories
  and collections only. The planned `expand=product_type` was never
  implemented and is cancelled.
- **Variant-level custom-field definitions deferred to 6.1** (no
  speculative `level` column in the join).
- **No shared value pools for custom fields — the plan's last open
  question, closed.** Both roles it conflated are already served:
  predicate search/sort/filter on custom-field strings shipped in 5.6
  (`SearchProvider::MetafieldSchema` + `with_metafield_filters`,
  storefront included) and stays string-based; faceted navigation over
  canonical values with counts is the OptionType/OptionValue role
  (disjunctive faceting shipped 5.4). Product-level descriptive facets
  (Vendure Facet / Saleor non-variant attributes), if ever demanded,
  get their own dedicated plan — never a custom-fields extension.

Adjacent, same review: **ShippingCategory stays removed** despite the
removal being unreleased. Medusa's ShippingProfile / Shopify's shipping
profiles are the same design as the category, but the 6.0 stack already
covers all three of its jobs (fulfillment-type eligibility matching,
`Splitter::FulfillmentType`, `excluded_delivery_method_ids`). The one
real loss — a *named* product grouping for delivery management — gets an
if-needed 6.1 successor as a named eligibility set or a
`DeliveryMethodRule` kind, recorded in `6.0-fulfillment-and-delivery.md`
("Named delivery groups"). Also on record: Spree never had a
variant-level shipping category (Solidus did), so product-level
`fulfillment_types` granularity is not a regression; the mixed
physical/digital product gap keeps a reserved relief valve (per-product
or per-variant `fulfillment_types` override, 6.1-if-needed).


## 2026-08-06: All three reason vocabularies are store-owned

`ReturnReason`, `ClaimReason` and now `RefundReason` include
`SingleStoreResource`. Name uniqueness moves from global to per-store, so
two stores can each have their own "Damaged" or "Order Canceled".

This is what makes the controller rule enforceable: every reason lookup
reads its matching association — `current_store.return_reasons`,
`current_store.claim_reasons`, `current_store.refund_reasons` — rather
than the model constant, so a prefixed id from another store is a 404
instead of a silent success — the
cheapest defence against IDOR, and now uniform across the returns surface
alongside `current_store.stock_locations`.

Refund reasons carried one wrinkle the others did not. Core looks three
of them up by name (`RETURN_PROCESSING_REASON` and friends) to attach to
refunds it issues itself, and a global `find_or_create_by(name:)` under a
per-store unique index would either find another store's row or create a
storeless one. The class methods therefore take the store explicitly —
`return_processing_reason(store)` — defaulting to `Spree::Current.store`
but never relying on it from a workflow, because a background job or
console session has no current store and would bind the reason to the
wrong one. All four call sites pass the store they already hold.

Existing rows are backfilled by `spree:upgrade:backfill_reason_store_ids`,
registered before `migrate_returns` in the 5.6→6.0 manifest. The
migration only adds the column — data transformations stay in rake tasks,
matching `backfill_delivery_and_stock_store_ids`.


## 2026-08-06: Return shipping labels are carrier output, not return state — cut from 6.0

`Spree::Return` briefly carried a `return_label_url` column written by a
`generate_label:` seam on `Returns::Approve`. The seam resolved its
provider through `Spree.return_label_provider`, which was never
registered in `Spree::Dependencies` — so the guard never passed and the
column was written by unreachable code. Both are removed.

The bug prompted the review; the market settled the direction. **No
comparable platform stores a label URL on the return record.** Medusa
returns `label_url` as part of a *fulfillment* (`FulfillmentLabel`) and
its own integration docs concede the default return flow "does not
provide enough data to create a full return shipment automatically";
Saleor's `Fulfillment` object exposes only `trackingNumber`, with labels
left to apps on webhooks; Vendure has no return-label concept at all,
producing labels as a side effect of a `FulfillmentHandler` calling a
courier API. A label is carrier output attached to a shipment, not a
property of the return.

Labels therefore ride with the carrier provider in
`6.0-delivery-rate-provider.md`, where an EasyPost/Shippo provider exists
to mint one and it can hang off a fulfillment like everywhere else. Until
then a store puts the URL in the return's `metadata`. This is the same
rule the return-policy decision (2026-08-03) applied: core ships a seam
when there is a real implementation behind it, never a speculative column
plus a provider key nobody declares.


## 2026-08-05: Dashboard form values must not embed SDK entity types

The returns rework regenerated the admin SDK types, and the new `Order`
embeds (`returns`/`exchanges`/`claims`, each carrying line items →
variants and refunds → payments) enlarged Order's transitive type
closure. That pushed TypeScript 6 over its relation-cache ceiling
("RangeError: Map maximum size exceeded") — killing `tsc -b` for the
whole dashboard — because the price-list form's rule drafts embedded
`Customer[]` (→ `orders` → the enlarged graph) inside the react-hook-form
values, and RHF's `Path<T>` enumerates every nested key of the form type.
The old types were merely under the ceiling; the API embeds themselves
are legitimate surface and were not changed.

The rule this settles: **form-values types carry opaque display records,
never SDK entity types.** `RuleEmbedRecord` (`{ id, name?, email?,
code? }`) in `schemas/price-list.ts` is the pattern — full SDK records
still flow in at runtime (covariant assignment), but the form type stays
shallow, so path expansion is O(form fields) instead of O(SDK graph).
`PromotionRuleFormDraft` embeds seven SDK types the same way and is one
graph-growth away from the same failure — apply the pattern there when
touched. Diagnostic note: `@typescript/native-preview` (tsgo) has no V8
Map ceiling, so it *reports* the offending comparison with a line number
instead of crashing — use it to locate this class of failure; keep tsc
as the build compiler.


## 2026-08-05: Reason CRUD ships admin-only; immutability moves onto the model

Dropping the legacy Rails admin left return, claim and refund reasons with
no editing surface at all, and the dashboard's create dialogs sent no
`reason_id` as a result — every return, claim and refund was created
reasonless, which quietly wasted the point of splitting return vocabulary
from claim vocabulary. Closed with three `ResourceController` subclasses
(`settings` scope), one combined **Settings → Reasons** page, and a reason
picker on the three create dialogs.

Two decisions worth recording:

- **`mutable` is not a writable attribute.** Core seeds reasons it looks
  up by name — `RefundReason.return_processing_reason` is attached to
  every refund a return issues — so letting a client flip the flag would
  hand it the ability to rename or delete the record the lookup depends
  on. `permitted_params` covers `name` and `active` only.
- **The immutability guard belongs on `Spree::NamedType`, not the ability
  layer.** The existing `cannot [:edit, :update], …, mutable: false` rule
  only fires for JWT users; secret API keys authorize by scope and never
  consult CanCanCan, so that path could rename a locked reason freely.
  The concern now carries `can_be_deleted?`, a rename validation and a
  destroy guard, keyed off `has_attribute?(:mutable)` so NamedTypes
  without the column are unaffected. This is the RBAC Axis A/B split
  applied as intended: capabilities in permission sets, record-state
  rules on the model.

Reasons have no Store API surface — they are back-office vocabulary — so
the serializers are admin-only and excluded from Store SDK generation.


## 2026-08-05: Legacy returns chain removed — tables kept, three capability replacements

The drop landed. Four decisions came out of doing it, each because
deleting the legacy code would otherwise have quietly removed working
behaviour:

- **The legacy tables stay through 6.0.** Only the Ruby classes are
  deleted. `spree_return_authorizations`, `spree_return_items`,
  `spree_customer_returns`, `spree_reimbursements`,
  `spree_reimbursement_types` and `spree_reimbursement_credits` remain as
  the data migration's source and its rollback path; they drop in 6.1
  once installs have run `spree:upgrade:migrate_returns`. A migration
  that deletes its own source in the same release has no way back.
- **`Order#outstanding_balance` drops the reimbursement term rather than
  replacing it.** `payment_total` is already computed net of refunds by
  `Carts::RecalculateTotals`, so returns and claims need no term of their
  own — the legacy reimbursement payout was the only money movement that
  sat outside that sum. A fully refunded order therefore shows its
  balance as outstanding again, which is what the pre-existing
  "refund without a reimbursement" test already asserted.
- **`Return#refunded_total` counts store credit as well as refunds.**
  Store credit is a separate ledger and never creates a `Spree::Refund`
  row, so summing refunds alone reported zero for a store-credit refund —
  wrong on the record, in the API, and in the customer's email.
- **The reimbursement email is replaced, not dropped.**
  `Spree::ReturnMailer#refunded_email` fires on `return.refunded`. The
  legacy template's expedited-exchange section has no counterpart in the
  new model and was not carried over.

Also renamed `StoreCreditCategory.default_reimbursement_category` to
`.default_refund_category` (deprecated alias kept one release), and
repointed `OrderStatusSubscriber` from the `return_item.*` events to
`return.received/refunded/canceled`.


## 2026-08-05: Returns/exchanges/claims — legacy drop scope, permanent *LineItem names, reason renames

The new returns system (`6.0-returns-exchanges-claims.md`) shipped to
6-0-dev: three entities, fifteen workflows, admin + store v3 APIs,
dashboard pages. Reviewing what remains settled four things:

- **`ReturnLineItem` / `ExchangeLineItem` / `ClaimLineItem` are the
  permanent names.** Chosen during implementation because legacy
  `Spree::ReturnItem` was still in service, they stay after the drop:
  they mirror `Spree::LineItem`, and renaming to the plan's shorter
  `*Item` would cost a table rename plus serializer/SDK/dashboard churn
  for nothing.
- **Reasons:** `ReturnAuthorizationReason` → `ReturnReason` (model +
  table rename, deprecated alias one release) plus a new `ClaimReason`
  model — claim vocabulary ("arrived damaged", "never arrived") is a
  different list from return vocabulary ("wrong size", "changed mind").
  `RefundReason` stays.
- **`spree:upgrade:migrate_returns` ships together with the legacy drop**,
  on the same branch, reading legacy tables via lightweight anonymous AR
  classes (the `migrate_users_to_customers` pattern) so it works after
  the models are deleted. Riding Wave 7 would have blocked the drop.
  Resumption needs no cursor, job or checkpoint table: the legacy
  `number` carries onto the new record and is uniquely indexed there, so
  the remaining work is a query rather than tracked state — which cannot
  drift out of sync with what was actually written.
- The drop scope: legacy models + STI reimbursement types + eligibility
  validators + v3 legacy serializers + seeds + permission-set grants +
  legacy tables (except `spree_return_items`, kept under its original
  name for historical reference until 6.1). `Spree::Metafields` lands on
  the three entities on the same branch.


## 2026-08-05: v5 developer docs are frozen until the 6.0 release; 6.0 docs land under docs/v6

The pages under `docs/developer/` document the stable 5.x line and stay
untouched until 6.0 ships — even where they describe subsystems 6.0 has
already replaced on main (the polymorphic `Adjustment` model, the
`AdjustmentSource` concern, and similar). Any plan whose remaining work
includes "update developer docs" fulfills it by writing a **v6 variant**
under `docs/v6/developer/` (registered in `docs/docs.json` under the
v6.x version), never by editing the v5 page. First applications: the
typed-adjustments docs (`v6/developer/core-concepts/taxes-discounts-fees.mdx`
already exists; promotions core-concepts and the custom-promotion how-to
get v6 variants). Also renamed `6.0-split-adjustments.md` →
`6.0-6.1-split-adjustments.md`: the implementation shipped for 6.0 and
the remainder (legacy-table drop, promotion stacking) is 6.1 work, so
the plan spans two releases like the other `X.Y-X.Z` plans.

## 2026-08-05: Customer registration graduates to a workflow; core sends no welcome email

Customer creation today runs through three paths with three different
side-effect sets: store self-registration links a matching newsletter
subscriber but sends no email; the checkout "create an account" box
(`Orders::CreateUserAccount`) adopts addresses and sends a welcome email but
skips subscriber linking; Admin API create does neither. A fourth path —
storefront OIDC auto-provisioning — is coming and would have reinvented all
of it again.

`Spree::Customers::Create` (seam `customer_create_workflow`, hooks
`customers.create.validate` + `customers.create.after_create`) unifies the
storefront paths. The `validate` hook is the point of the exercise:
bot/disposable-email screening, fraud checks and B2B registration approval
all need to *veto* a signup, which the `user.created` lifecycle event
cannot do. The workflow takes an optional `order:` and absorbs
`Orders::CreateUserAccount` entirely (one flow = one workflow — the
Orders::Complete precedent); the old class stays as a deprecated one-release
shell. Explicitly outside the workflow: Admin API create (plain CRUD — staff
creation must not be blockable by registration-policy hooks; handlers that
want to distinguish anyway read `created_by`, the return-eligibility
pattern) and JWT/refresh-token issuance (HTTP session concern, stays in the
controller).

Checkout-created accounts are **password-less** (the old service generated a
random password): blank is the one unclaimed-account state — same as
admin-created customers — `Customer#valid_password?` guards the blank digest,
the account is claimed via password reset, and a generated value could fail a
host's swapped-in `Spree.password_validator`. Self-registration still requires
a password, because the caller issues a JWT on success. The
`password_required:` keyword carries that rule: it defaults to **false when
`order:` is present** (guest checkout collects no password) and **true
otherwise**, and an explicit value always wins — which is how a future
provisioning caller with no order (OIDC, invitations) waives the requirement
deliberately rather than by faking an order.

**The welcome email leaves core.** The only sender was the checkout path
(`user.send_welcome_email if user.respond_to?` — self-registration never
sent one, which was an accident of the split, not a choice). Signup email is
host-app implementation via a `user.created` subscriber or the
`after_create` hook — the same stance `spree/emails` already takes for
headless storefronts owning consumer email.

**Upgrade step (host applications).** A host that relied on the checkout
welcome email — i.e. defines `send_welcome_email` on its customer class — must
move the send itself, since core no longer calls it. Either subscribe to
`user.created` (fires on every creation path, including admin and imports) or
register a handler on `customers.create.after_create` (storefront registration
only). The method itself can stay; nothing in core invokes it any more.

Plan: `6.0-service-workflows.md` decision 13.

## 2026-08-04: Commerce-behavior globals move to Store preferences; app configuration stays global

A full usage audit of `Spree::Config` (multi-agent trace with adversarial
verification over all 68 preferences) found 38 genuinely live settings, 6 read
only by subsystems 6.0 replaced, and 7 with zero read sites anywhere. One of the
38 — `default_stock_reservation_ttl_minutes` — has a read site but is *silently
unreachable*: the Store preference it falls back from carries its own default
and a `> 0` validation, so it is never blank. Both default to 10, so nobody
noticed.
That failure mode is the argument for the whole decision: two sources of truth
for one behavior, where one quietly wins and the documentation becomes a lie.

**The classification test:** would a second store on the same installation
plausibly want a different value? Yes → the setting belongs on `Spree::Store`
(an EU store needs `track_price_history`; its sibling doesn't). No → it stays
in `Spree.config` (password length protects the app, not a shop).

Nine globals move in 6.0 — `auto_capture` (the per-payment-method column still
wins when set), `auto_capture_on_dispatch`, `allow_checkout_on_gateway_error`,
`track_inventory_levels`, `stock_reservations_enabled`, `track_price_history`,
`show_products_without_price`, `address_requires_phone`,
`disable_sku_validation`. The store preference is **authoritative with no
runtime fallback to the global**; existing installs carry over through
`spree:store_settings:backfill_from_config` in the upgrade manifest, and the
globals live one release as deprecated shells. A fallback chain was explicitly
rejected — it is the shape that produced the unreachable TTL. This finishes the
migration `company` → `Store#company_field_enabled` and `allow_guest_checkout`
→ `Store#guest_checkout` already started.

Two readers have no record-level store: `Address` (no association) and the
class-level product availability scope. Both read `Spree::Current.store` and
fall back to the declared default. The trade-off is accepted knowingly —
validation or a catalog query outside a request uses the default — because the
alternative, threading a store argument through every caller and breaking a
public scope, is disproportionate. Jobs touching those paths must set
`Spree::Current.store`.

`track_price_history` goes to Store rather than Market despite Omnibus being
per-country law: Market already owns `return_window_days` and the other legal
settings, but prices are not market-scoped today, so a Market home needs design
this plan won't carry. Noted as a 6.1 refinement. Two behavior-looking settings
stay global: `credit_to_new_allocation` (ledger-shape convention — per-store
variance corrupts one install's accounting) and `non_expiring_credit_types`
(reference data).

Corollary settled at the same time: **new behavior flags are born on Store** (or
Market/Channel where regional), never in `Spree.config`. Also retired on the
evidence: `reserve_stock_on` (the Cart/Order split wired reservations into the
cart flows gated on `stock_reservations_enabled`; the trigger switch was never
read — superseding note added to `6.0-stock-reservations.md`) and the confirm
checkout step as a configuration concern (`confirm` is advertised, never
enforced — a storefront renders a review screen when it wants one;
`PaymentMethod#confirmation_required?` is the real, unrelated requirement).
Plan: `6.0-store-scoped-configuration.md`.

## 2026-08-03: Return eligibility ships as a hook, not a policy engine — enforced in the workflow, scoped per market

A survey of Shopify, Medusa, Saleor and Vendure settled how far 6.0 goes on
return policy. **Core ships the seam and no policy**: a `validate` hook on
`Returns::Create`, `Exchanges::Create` and `Claims::Create`, with no return
window, restocking fee or final-sale flag anywhere in core.

**What the survey found.** Medusa, Saleor and Vendure ship *no* return
eligibility policy at all — not a different approach, genuinely nothing. Only
Shopify has an engine (window with a delivery-date anchor, percentage
restocking fee, final-sale product/collection lists, per-market rule sets), and
it exposes **no API for any of it**; configuration is admin-UI only.

The seam comparison mattered more than the feature list. Medusa built a hook
system, exposed `setPricingContext` on returns, and deliberately did not expose
a validation hook — policy has to live in route middleware or a replaced
workflow. Saleor built the filter-veto webhook shape for shipping and never
generalized it to returns; an external app decides eligibility itself and calls
the staff mutation, which never asks permission. Vendure's `onTransitionStart`
returning `false | string` is the only comparable veto and hangs off a state
machine rather than a return flow; its RMA issue is open at priority P4.

So `validate` + `reject!(message)` is already the strongest extension point in
the field. A `ReturnPolicy` model with STI rules would be the most capable
thing on the market by a wide margin and entirely speculative — no competitor
has demonstrated the demand, and the hook carries one later without changing
its contract. Deferred, not rejected.

**Enforce for customers, advise for staff.** The one lesson worth copying from
Shopify: eligibility is enforced on the customer surface and advisory on the
staff surface. A Shopify staff member can create a return on a final-sale item
outside the window; the customer API refuses. Their `returnableFulfillments`
deliberately ignores return rules because it mirrors the admin, "where any
authorized staff can create returns." A handler that rejects unconditionally
would be stricter than Shopify — a supervisor overriding policy for a good
customer is ordinary retail.

**This lives in the workflow, not the model.** Eligibility is a decision made
during a flow with the caller's context in hand — who is asking, and whether
they may override — not a property of a return record. `Returns::Create` takes
`created_by` (nil for customer self-service, set for staff) and the handler
decides what that means.

**Per market, not per store.** Return rules are legal before they are
merchandising: the EU right of withdrawal is 14 days minimum, US practice is
the merchant's choice. `Order belongs_to :market`, and
`5.4-6.0-eu-legal-compliance.md` already puts `withdrawal_period_days` and the
other legal settings on Market, so a handler reads its window from
`order.market`. Shopify reached the same conclusion — its per-market rule sets
exist specifically for EU compliance.

Also noted from Shopify but **not adopted in 6.0**: rules are snapshotted onto
the order at placement, so changing a window never retroactively invalidates a
pending return, and non-returnable reasons are tracked per *quantity* rather
than per line item. Both are right, and both belong with a policy engine rather
than ahead of one.

## 2026-08-02: Workflows replace state machines for new models; hooks ship on the 6.0 boundary; OrderChange substrate targets 6.1

A review of our workflow and extension surface against the wider ecosystem
settled three things.

**1. New models get no state machine.** The returns/exchanges/claims draft gave
each of `Return`, `Exchange` and `Claim` a `state_machine :status` block with
the real work on transition callbacks (`after_transition to: :received,
do: :restock_items`, `do: :process_refund`). That is now removed: plain `status`
string column, inclusion validation, generated predicates, and every transition
is a workflow.

Why: a transition callback runs inside the transaction that saves the status
column, so `process_refund` would put a gateway call inside a database
transaction — the exact failure `Carts::Complete`'s three-phase design exists to
prevent. Transitions also take no arguments, and every real return is partial
("two of three arrived, one not resellable") with nowhere to put that input;
there is no compensation story where `on_flow_failure:` is; and guards raise
`StateMachines::InvalidTransition` instead of returning an inspectable `Result`.
The stated purpose of that plan was escaping six interlocking state machines —
replacing six with three is a difference of degree, not of kind.

The precedent had already shipped: the Order state machine is gone in 6.0, and
`Orders::Cancel`/`Orders::Resume` absorbed `Order#after_cancel`/`#after_resume`,
moving gateway settlement out of the transaction in the process.
`state_machines-activerecord` stays a dependency for the legacy models through
6.0; it is simply not used on anything new.

**2. Hook keys are public API, so they ship on the breaking-change boundary.**
The doctrine's "a service graduates the moment it earns a hook — never
speculatively" was written to stop speculative abstraction, and it still governs
*workflows*. It does not govern *hooks on flows already in the workflow tier*.
Adding a hook later is cheap; *moving* one means restructuring a flow extensions
have registered against, which breaks them. 6.0 is the window. A documented,
coherent extension surface is itself the demand, so hooks are placed
deliberately across the existing workflows now rather than one merchant request
at a time. Two closed waves (see `6.0-service-workflows.md` Phase 3): Wave A
adds `validate` and lifecycle hooks to the existing workflows; Wave B graduates
four services that already qualify on external I/O or orchestration
(`Fulfillments::Create`, `Payments::Capture`/`Refund`,
`Payments::HandleWebhook`, `Carts::Merge`).

Three hook families are now named: **lifecycle** (past tense, react, cannot
change the outcome — what we ship today), **validation** (`validate`, reject
before the work — the most-requested seam, currently only reachable by replacing
a whole service class), and **context** (`set_pricing_context`,
`get_provider_data` — feed data *into* a calculation). Context hooks are
**blocked**: they need handlers to write back, and `run_hooks` currently
dispatches the workflow instance for reading only. Do not ship a `set_*_context`
hook until that contract is settled.

Explicitly rejected: workflows for plain CRUD. Wrapping every region, tax-rate
and API-key write in a workflow class would add hundreds of pass-through
classes with no hook, no compensation and no external I/O. Workflows are earned
by orchestration, not by being a write.

**3. The OrderChange substrate targets 6.1, not 6.0**
(`6.1-order-change-substrate.md`). One `OrderChange` + `OrderChangeAction` pair
behind every post-placement mutation — admin order edits, returns, exchanges,
claims, draft-order amendments — with a `begin → request → confirm → cancel`
lifecycle, so those flows stop inventing four separate draft models and four
separate "what will this cost" calculations. It is deferred because it is new
schema plus a new extension API, and 6.0 already carries the Cart/Order split,
typed adjustments, the fulfillment rename and the returns rework; designing it
under time pressure against three consumers that are themselves still landing
is how it would go wrong. The 6.0 returns work ships on its own status flows and
adopts the substrate additively in 6.1 via a nullable `order_change_id`.

Two constraints apply to 6.0 work in the meantime: **do not persist a financial
preview** (compute in memory and discard — a persisted per-domain draft would
have to be migrated onto the substrate later), and expose post-placement money
math through a service returning a value object so callers can be re-pointed
without changing.

**4. Hook contracts and configurable statuses (settled interactively the same
day), which unblock Wave A:**

*Context hooks collect and deep-merge handler return values.* A handler returns
a hash; `run_hooks` merges every handler's hash in registration order and
returns it. Chosen over a mutable context object because handlers stay pure and
independently testable, with no order-dependent shared state. `run_hooks`
returning a value is additive — lifecycle hooks ignore it. Last writer wins on
a key collision, reported via `Rails.error.report` in development so two
extensions fighting over one key is visible. **This unblocks the context-hook
family** — `set_promotion_context`, `set_tax_line_context` and
`get_provider_data` now ship in Waves A and B rather than being deferred.

*`validate` handlers reject with `reject!(message)`* — a purpose-named method
wrapping the existing failure path (raises `FailureSignal`, unwinds the undo
stack, rolls back an open transaction). Preferred over reusing `failure(...)`
so "an extension vetoed this" stays legible against "this step failed", and
over a falsy return value, where a stray `nil` would abort a flow by accident.

*Statuses are configuration, not frozen constants.* `Spree::HasStatus` holds
values in a `class_attribute` with an additive `add_status(value, after:)`, so
a merchant can add an `inspecting` step between `received` and `refunded`
without reopening core. This follows the established `class_attribute` pattern
for genuinely configurable collections (`DeliveryZoneMember.range_capable_country_isos`,
`RichTextSanitizer.allowed_tags`) rather than the frozen-constant pattern used
for closed value lists.

**Additive only — wholesale replacement is not offered.** Core workflows guard
on core statuses (`Returns::Refund` requires `received?`); letting an extension
drop one would silently break core flows with no error at the point of removal,
because the guard would simply never pass. Adding is safe, removing is not, so
the API exposes only the safe half.

`add_status` deliberately takes **no `from:`/`to:` transition graph**. A custom
status needs a custom workflow to move records into it, which is the intended
shape, not a gap: validating transitions centrally is a state machine by
another name — precisely what ruling 1 removes.

**5. Two smaller rulings from the same session.**

*Refunds branch on method, not blanket `external_step`.* Store credit and gift
cards are internal ledger writes, so routing them through `external_step` would
push a pure database write outside the transaction that marks the return
refunded — a crash between the two leaves a refunded return with no credit
issued. `Returns::Refund` (and `Claims::Resolve`, `Exchanges::Fulfill`) keeps
internal credit inside the transaction and sends only gateway refunds outside
it. Precedent: `Orders::Cancel#settle_payments` already distinguishes
gift-card-covered payments from gateway payments.

*`with:` step swapping stays a core-only seam in 6.0.* The public extension
surface is hook keys and their contracts, `reject!`, `Spree::Dependencies`
class swapping, `has_status`/`add_status`, and workflow `#perform` signatures.
Step names, step boundaries and `with:` targets are explicitly internal —
documenting them would freeze internal structure we still expect to refactor
during the 6.0 finishing work, in exchange for granularity that hooks largely
already provide. Revisit in 6.1 once real hook usage shows what is missing.

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
- `spree_customer_group_users.user_id` → `customer_id` (polymorphic — `user_type` also renames to `customer_type` so `belongs_to :customer, polymorphic: true` resolves)

**Keep as `user_id`** (5 models — FK references Spree.admin_user_class or is polymorphic):
- `spree_imports.user_id` — admin who ran the import
- `spree_exports.user_id` — admin who ran the export
- `spree_reports.user_id` — admin who generated the report
- `spree_state_changes.user_id` — references the order's **customer** (set from `order.customer_id`), not an admin. Kept as `user_id` because it's an internal state-audit log, not customer-facing API surface; the `belongs_to :user` association resolves to `Spree.customer_class`.
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
regardless (`6.0-6.1-split-adjustments.md`): typed Discount tables that permit
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

## 2026-07-29: Phase 2 user→customer data migration — copy-preserving-id, in-place admins, single clash-aware migration

Implementing Phase 2 of `6.0-platform-auth.md` settled several mechanics.

**Customers are a row copy, admins are in place.** The 6.0 split is already
two-table (`spree_users`=customers, `spree_admin_users`=admins; admin-ness is a
polymorphic `spree_role_users.user_type`, not a table). So `spree_customers` is a
**new** table and its data comes from copying `spree_users` — it cannot be a
`rename_table` (the create migration always runs, so the target already exists;
fresh installs have no `spree_users`; and `spree_users` carries Devise cruft).
`spree_admin_users` keeps its table **and** its class name `Spree::AdminUser`, so
admins never move — the task only backfills `password_digest` from the legacy
`encrypted_password`.

**Copy preserves primary keys** so the already-renamed `customer_id` FKs
(2026-03-16 entry) still resolve with no id remap. This is the first repo task to
insert explicit ids, so it also **resets the Postgres sequence** afterward
(`reset_pk_sequence!`, guarded to PG) — no prior precedent because taxon→category
preserved ids via `rename_table`. With ids preserved, the only polymorphic fixups
are **type-string re-points** `Spree::User` → `Spree.customer_class` on
`spree_role_users`, `spree_refresh_tokens`, `spree_user_identities`,
`spree_api_keys` (`created_by_type` + `revoked_by_type`), and
`spree_customer_group_users` (whose type column renamed `user_type` →
`customer_type` with the 2026-03-16 FK rename — **must** be re-pointed too or
memberships dangle); admin-typed rows stay. The task reads the legacy table **by
name only** (never `LegacyUser`, deleted once all phases ship together), aborts on
`Devise.pepper` (and, since Devise is gone in 6.0 and a pepper can't be
introspected, aborts when Devise is absent unless `CONFIRM_NO_PEPPER=true`),
preflight-aborts on blank-email or email-conflict rows (`SKIP_INVALID_ROWS=true`
to skip), and leaves `spree_users` in place as a safety net.

**Single clash-aware create migration.** The two Phase-1 create migrations merged
into `20260728000000_create_spree_customers_and_admin_users` — a **non-colliding**
name, because `install:migrations` de-dupes engine migrations by name and every
existing app already has a `create_spree_admin_users`, so the gem's same-named
migration is skipped and never runs on upgrades. The merged migration creates
`spree_customers` cleanly and guards the admin side
(`create … unless table_exists?`, `add_column :password_digest unless
column_exists?`). `password_digest` is **added alongside** `encrypted_password`,
never a rename — nothing is lost, and the backfill has both columns to read.

**Path B is a recipe, not gem code.** Keeping a custom user model needs no new
concern: on the app's own model, `include Spree::CustomerMethods` +
`has_secure_password validations: false` + `alias_attribute :password_digest,
:encrypted_password` (or a column rename). The alias must live on the app model —
a blanket alias in `CustomerMethods` would shadow the default `Spree::Customer`'s
real `password_digest` and break `has_secure_password` on it.

The 5.6→6.0 upgrade guide (`docs/developer/upgrades/5.6-to-6.0.mdx`) doesn't exist
yet (6.0 in-dev); Path A/B developer guidance currently lives in the task's `desc`,
the `5_6_to_6_0` manifest notes, and this plan. It moves to the mdx when the full
6.0 upgrade guide is authored.

## 2026-07-29: Account lockout enforced in the auth strategy; thresholds config-driven

Phase 4 of `6.0-platform-auth.md` was mostly already shipped (RefreshToken issue/rotate/revoke,
login/refresh/logout endpoints, Rails `rate_limit` throttling). The remaining gap was that the
lockout methods on Customer/AdminUser were **dead code** — nothing in the login path called them.

Decisions made wiring it up:

**Enforcement lives in `EmailPasswordStrategy`, not the controllers.** The strategy is the single
point both store and admin login flow through, and it's the only layer that holds the user object on
a *failed* password (the controllers get a generic failure). So `authenticate` checks `locked?`
before validating, `record_failed_attempt!` on a bad password, and `reset_failed_attempts!` on
success. All calls are `respond_to?`-guarded so a Path-B custom `customer_class` without the lockout
methods still authenticates.

**Thresholds moved to `Spree::Config`, logic to a shared concern.** The identical
`locked?`/`record_failed_attempt!`/`reset_failed_attempts!` on both models (with hardcoded `5` /
`30.minutes`) were extracted into `Spree::AccountLockout` (core concern) reading
`Spree::Config[:max_failed_login_attempts]` (5) and `[:lockout_duration]` (1800s). These are **core**
prefs (not `Spree::Api::Config`) because the concern lives on core models, which can't depend on the
API config.

**Distinct lockout message** ("Account temporarily locked. Try again later.") over a generic
invalid-credentials response — industry-common, and login is already rate-limited so the marginal
enumeration signal is low. It's a single return string, easily switched to the generic message if a
stricter anti-enumeration posture is wanted (Spree's login/password-reset are otherwise
anti-enumeration).

**Refresh-token hashing at rest was declined** (tokens are already random + expiring; login
throttled). **Admin `logout` gained a `rate_limit`** to match the store side. Following the repo's
rate-limit spec convention, no throttle-*trip* test was added (those depend on the test cache store);
the existing specs cover response format/headers/config.

## 2026-07-29: Devise fully removed from core/api; legacy models deleted, table kept

Phases 5 & 6 of `6.0-platform-auth.md`, scoped to `spree/core` + `spree/api` (spree/admin removed
wholesale by `6.0-admin-spa.md`; the spree-starter / 5b changes are a separate pass).

**Legacy models deleted, `spree_users` table retained.** `Spree::LegacyUser` /
`Spree::LegacyAdminUser` are gone (no runtime fallback — `Spree.customer_class` has no default,
`Role` is dynamic, and only four specs named the constant, all repointed to `Spree.customer_class`).
The `spree_users` **table** is deliberately kept as the Phase 2 migration's safety net — its teardown
is a separate later operator task, and the 4.3 baseline migration still materializes it on fresh
installs.

**Devise bridges removed, not kept.** Both `Spree::AdminUserMethods::DeviseNotifications` and
`CustomerMethods::SkipPasswordValidation` were deleted. They were inert on the gem's
`has_secure_password` models: admin auth emails flow through the `admin_user.password_reset_requested`
event subscriber → `AdminUserMailer` (not `send_devise_notification`), and password-less
admin-created customers rely on `has_secure_password validations: false` rather than a
`password_required?` override. The `defined?(Devise)` guards in the migrate-users rake task are the
one Devise reference kept — they're defensive checks for installs migrating *off* Devise.

**`spree:install` scaffolds no auth by default.** With the generators deleted, the root-gem install
generator's `--authentication` default moved to `nil` (was `devise`): a plain install writes no auth
helpers because the gem owns auth (`Spree::Customer`/`Spree::AdminUser` + the initializer sets the
class names). `dummy` stays available and is what the test harness passes explicitly via
`common_rake`, so `test_app` is unaffected.

**Deprecation aliases kept to 6.1.** The earlier Phase 6 plan to drop the `user_class` alias in 6.0
is superseded — `Spree.user_class`, `Spree::UserMethods`, `Spree::DeprecatedCustomerAlias`, and the
`:user`/`:admin_user` factory aliases all remain through 6.0 (in-code comments already tag them 6.1).

**Docs.** The Devise-as-default pages were rewritten around gem-owned auth + the custom-model recipe,
and `Spree.user_class` references swept to `Spree.customer_class`. `Spree::OauthAccessToken` is a
no-op (extracted upstream). Deferred: the 6.0 upgrade guide, the `spree_users` teardown task, and the
unrelated search-area `multi_search` alias removal.

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


## 2026-07-29 — Every major model carries a store_id; DeliveryZone bound now, StockLocation next

Ratifies the principle already stated in `6.0-delivery-rate-provider.md`
(DeliveryMethod gets `store_id` there) as a standing convention: new
models carrying store-specific data always `belongs_to :store` through
`Spree::SingleStoreResource`; only genuinely global reference data stays
unscoped. Store binding also closes cross-store lookup holes structurally
— admin controllers scope `current_store.<resources>` instead of relying
on ability scoping alone (see the Strix findings on delivery-method
bindings, 2026-07-29).

Applied immediately to **DeliveryZone** — an unreleased 6.0 table, so the
creation migration gained `store_id NOT NULL` + per-store name uniqueness
in place, with zero bridge cost. **DeliveryMethod and StockLocation**
(released tables) landed on the same branch via the 5.6 single-store
pattern: nullable `store_id` + `SingleStoreResource`, per-store seeds,
manifest backfill task assigning the default store, `null: false` in
6.1. (Cross-store sharing is not preserved anywhere — `spree_multi_store`
is legacy and unsupported.) Admin lookups and runtime pickers (Estimator, Coordinator, order
routing) all go through the store associations
(`store.delivery_methods` / `store.stock_locations`) — strict semantics;
the manifest backfill is a required upgrade step before checkout. **TaxRate and
TaxCategory** follow inside the tax-provider plan's implementation
(noted there). Stock availability (`Stock::Quantifier`) intentionally
stays location-global until the 6.1 NOT NULL work — correct for
single-store installs, revisited with multi-store.


## 2026-07-30 — Credential homes follow cardinality: Integration for store-level connections, PaymentMethod rows for merchant entities

Provider architecture is three layers: store-owned commerce config rows
(DeliveryMethod, PaymentMethod), stateless registry-keyed provider code
(FulfillmentProvider/DeliveryRateProvider/tax engines — never hold
credentials), and `Spree::Integration` as the per-store credentialed
vendor connection (one row per store+type, `can_connect?`, admin
listing). Where credentials live is decided by cardinality, and the two
domains are deliberately opposite:

- **Delivery/vendor APIs — one connection, many methods.** An EasyPost
  account rates every method; config rows multiply, the connection does
  not. Credentials belong on the Integration singleton; provider gems
  ship an Integration subclass + a stateless provider pair
  (`6.0-delivery-rate-provider.md`).
- **Payments — one credential set per merchant entity, several per
  store.** Two Stripe accounts are two merchants of record (separate
  settlement and liability), selected per market at checkout — exactly
  what PaymentMethod rows model, gated by MarketRule once
  `5.7-payment-method-rules.md` lands. Credentials stay on the method
  row; converging them onto Integration would fight its store+type
  uniqueness and is explicitly NOT planned.

Consequence for tax (`6.0-tax-provider.md`): "one Stripe connection
serves payments and Stripe Tax" only holds single-entity. Under multiple
merchants of record, tax liability follows the charging entity per
market — a Stripe Tax provider must resolve credentials consistently
with the market's selected payment entity, not via a store-singleton
Integration lookup.


## 2026-07-30 — Reference providers: Stripe (payments), Avalara (tax), EasyPost-or-Shippo (delivery)

One first-party reference implementation per provider seam, each
exercising its layer's canonical shape from the credential-cardinality
entry above: **Stripe** for payments (monorepo move per 2026-07-15 —
credentials on PaymentMethod rows, multi-entity capable), **Avalara**
for tax (the enterprise standard, matching the enterprise-seller target;
Integration subclass for store credentials + stateless provider writing
TaxLines with `provider_id: 'avalara'`; the built-in `'internal'` engine
stays the OSS default), and the **EasyPost-or-Shippo** multi-carrier
gem for delivery rates (pick still pending; Integration + provider
pair). Stripe Tax remains buildable by third parties but is not the
reference — and carries the merchant-of-record caveat recorded above.


## 2026-07-30 — Service workflows: one step DSL, Carts::Complete as the stress test

Services, sagas, extension hooks and events unify under a declared step
DSL evolved from ServiceModule in place (plan:
`6.0-service-workflows.md`, targeted 6.0). Medusa's workflows are the DX
benchmark; the runtime stays plain Ruby in Rails transactions — no
engine, no execution-state tables. Explicit transaction/io_step
boundaries, per-step compensation, in-transaction `hook` extension
points and declared `emit` events; the consistency doctrine (step →
sync subscriber → async subscriber) ships as documentation.
**Carts::Complete is the reference implementation and acceptance test:**
the cart→order swap already exercises every hard property (in-lock
verification, out-of-transaction payment I/O, compensation, replay
idempotency, sweeper resume) and its spec battery must pass unmodified
after the retrofit. Durable flows compile onto ActiveJob Continuations
in Phase 2 (imports, upgrade migrations, payout runs) and may land
post-GA without blocking the DSL.


## 2026-08-06 — Per-product delivery exclusions are a delivery-method rule, not a product column

`spree_products.excluded_delivery_method_ids` (JSON array, shipped with
the fulfillment rework but never writable through any API or UI) is
dropped in favor of `Spree::DeliveryMethodRules::ExcludedProductsRule` —
products attached through the concrete
`spree_delivery_method_rule_products` join table. Rationale: an ID list
in JSON is unqueryable and unindexable portably across the three
supported databases, rots when delivery methods are deleted, and would
have needed its own bespoke API/serializer/UI surface; the rules
framework already ships the registry, nested admin CRUD, discovery
endpoint and dashboard Conditions card. It also removes the second
eligibility seam inside `Stock::Package#eligible_delivery_methods` —
the rules plan mandates the Estimator's rule filter as the only one.
Method-side exclusion matches Saleor (`excludedProducts`); Shopify and
Medusa model the inverse via shipping profiles (≈ the retired
ShippingCategory), Vendure is code-only. Companion convention — storage
by cardinality: small reference sets (channels/markets/customer groups)
stay `:array` preferences via `normalize_id_preference`; catalog-scale
references (products) get a join table, per the
`Promotion::Rules::Product`/`ProductPromotionRule` precedent. On the
wire both travel as prefixed-ID params resolved through the store scope
and `accessible_by(current_ability, :show)`. Plans updated:
`6.0-delivery-method-rules.md` (owner),
`6.0-fulfillment-and-delivery.md`, `6.0-core-rewrite-tasks.md`.


## 2026-08-06 — STI rule families declare their subclass registry

`Spree::PreferenceSchema.registered_subclasses` resolved a class's
registered subclasses by matching two hardcoded class names
(`Spree::PromotionAction`, `Spree::PromotionRule`) and otherwise
returning `[]`. Four families had each worked around that with a private
per-class override in three different idioms (`PriceRule`,
`OrderRoutingRule`, `CollectionRule`, `DeliveryMethodRule`), and
`5.7-payment-method-rules.md` specced a fifth. The empty-list fallback
failed **silently**: `find_by_api_type` returned nil, so
`TypedAssociations` dropped typed rows from a payload with no error and
`subclasses_with_preference_schema` rendered empty admin pickers — the
bug that broke `DeliveryMethod#rules=` on first attempt.

Replaced with a declarative hook: each STI parent calls
`registers_subclasses_via { <registry> }` (one line), stored in a
`class_attribute` so STI subclasses inherit the parent's declaration —
resolving on a subclass works, which it did not before under either
scheme. A class that declares none raises
`Spree::PreferenceSchema::UndeclaredRegistryError` (a **StandardError**,
so host apps' `rescue => e` catches it — `NotImplementedError` descends
from `ScriptError` and would slip past). Migrated in place:
PromotionRule, PromotionAction, PriceRule, OrderRoutingRule,
CollectionRule, DeliveryMethodRule, and **PaymentMethod** — gateways
declare `registers_subclasses_via { providers }` rather than being a
special case in the resolver, so there is exactly one resolution rule.
`5.7-payment-method-rules.md` updated to the new form.

Known debt: the registry is a lodger inside `PreferenceSchema` (which
`Spree::Base` includes, so ~200 models carry class methods only six use),
and `Spree::CalculatedAdjustments` resolves an equivalent registry
separately. Extract a `Spree::RegisteredSubclasses` concern when a family
needs the registry without preferences — that second consumer is the
trigger, and it would absorb CalculatedAdjustments too.
