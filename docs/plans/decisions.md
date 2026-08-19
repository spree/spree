## 2026-08-16: A vendor's status is something that happened to it, not a field you set

Damian asked for vendor management with "invitation, approvals, all in
workflows". Recording why the API refuses the obvious shortcut.

**The shortcut we did not take.** A `status` in `permitted_params` would have
made the whole lifecycle one endpoint. It is also how the transitions stop
meaning anything: approving a vendor sends mail, provisions payouts and is the
moment extensions want to hook — none of which happens when the value arrives
by mass assignment. So each move is its own workflow (`Spree::Vendors::Invite`,
`Approve`, `Suspend`, `Reject`), reached through its own member action, and
`status` is simply not writable. Consistent with returns and claims, which
already ship this way.

**The guards admit more than the happy path**, because the interesting moves
are the ones back. `Approve` lifts a suspension and revives a rejected
applicant, and it clears holiday mode on the way — a vendor coming back is
coming back to sell, and leaving them invisible would look like the approval
had not worked. `Suspend` and `Reject` are not synonyms: suspension is for a
vendor already trading and can be undone; rejection is for one that never did.
Rejecting an approved vendor is refused rather than quietly aliased, because
the two say different things to the person on the other end.

**Reasons live in metadata, not columns.** A suspension reason is a note about
one event; the next suspension has its own. A column would hold only the most
recent and read as though it described the vendor.

**Creating a vendor is not a transition**, so it stays plain CRUD and the
default status is applied in an `after_initialize`, following
`Spree::Fulfillment`. Only the moves are workflows.

**Managing sellers is staff-only.** `read_vendors`/`write_vendors` are not
offered to the vendor audience: a seller administering other sellers is the one
thing that key must never allow.

## 2026-08-16: Several sellers share a product by sharing it — the seller is on the variant, not on an offer record

Damian's call, after a survey of how marketplace platforms model a shared
catalog and an audit of what it would cost Spree.

**The gap.** The marketplace plan assumed one product, one seller. Two sellers
of the same book produced two unrelated products and two listings. That suits
unique goods and fails commodities, and it is the capability the legacy module
was most often asked for and could never provide.

**Why not an offer record.** Every surveyed implementation introduces one, and
every one of them is built on top of a commerce engine or a merchant's existing
catalog — they cannot put a seller on the variant and cannot re-key inventory.
Their offer is a variant they were not permitted to write. We own the variant.
An offer here would duplicate its seller, sku, price, stock, condition and
delivery config, and would cost a second pricing pipeline, a stock-anchor
migration (stock items are uniquely keyed on `(variant, stock_location)`), a
new line-item FK with the cart's variant-keyed deduplication reworked around
it, and offer-relative rewrites of the purchasability predicates. Putting the
seller on the variant makes all of that true by construction: two sellers are
two variant rows, so two stock rows; prices resolve unchanged; and the line
item already reaches the seller through the variant it points at — which is
exactly what the order split partitions on.

"Offer" survives as storefront vocabulary. Presentation need not be a table.

**Condition is an OptionType**, so it splits the variant like any other axis
and inherits the option machinery. That also makes the buy box key on the
option combination, giving the industry's separate new/used featured offers
without a second mechanism.

**An audit found four things that must ship with it**, three of which are
pre-existing faults the change would expose rather than create: `Product#variants=`
destroys variants absent from the payload, so removal must be filtered to the
writer's own or a narrower read would make the write destructive; delivery
profile is product-level and memoised per product, so sellers would share
whichever profile resolved first (fixed by a variant-level override, which
follows `Variant#tax_category` exactly and is worth having for plain merchants);
option filtering matches each option type independently against the product, so
"Blue AND XL" already matches a product with no Blue XL variant; and product
rollups become buy-box-relative, which is what makes them correct again rather
than a change of meaning.

**Operators see every seller's variants** — they run the marketplace. Seller
isolation is the vendor API branch scope-fetching through `current_vendor`
(Decision 10), not a narrowing of the admin surface.

**Catalog matching stays out of core.** Deciding two submissions are the same
item is hard enough that several platforms sell it separately. Core ships exact
matching on a typed identifier, with the namespace stored rather than inferred
from the value's shape; fuzzy matching is an extension.

Supersedes the plan's "SKU uniqueness relaxes to per-vendor scope" line, which
assumed duplicate product rows per seller.

## 2026-08-16: Grant audiences are a vocabulary, not a vendor flag

Phase 0 of `6.0-multi-vendor-marketplace.md`. Damian's call, after
re-examining the vendor principal question against a primary-source read of a
leading open-source marketplace platform.

**The principal decision stands, and the survey explains why it differs
elsewhere.** The surveyed platform separates *credential* from *principal*: a
standalone identity record holds the password, and it points at either an
operator principal or a seller principal, with the token naming which one is
acting. Spree has no such split — `Spree::AdminUser` **is** the credential
(`has_secure_password`, lockout, password policy, reset tokens, SSO identity
linking). Reproducing that shape means either a second copy of the whole auth
stack or rebuilding the shipped one. So Decision 10 holds: one `AdminUser`,
several hats, the surface distinguished by JWT audience. Worth noting the
convergence — that platform's per-request seller header and its token-level
actor tagging are the same two mechanisms Decision 10 specifies.

**Where the boolean was wrong.** The first cut marked catalog resources with
`vendor_grantable: true`. But `Role#audience` is already a *string* vocabulary
(`staff` | `vendor`), and the B2B plan anticipates company roles as a separate
future system — so the catalog would have needed a second boolean the moment a
third panel appeared, then a third. The catalog now carries `audiences:` — the
audiences *beyond staff* a resource opens up, staff being the implicit
baseline every resource grants — and `grantable_keys(audience)` replaces the
vendor-specific reader. An unregistered audience returns an empty set rather
than raising, so a panel that does not exist yet reads as granting nothing.
The vocabulary itself stays a constant on `Spree::Role` rather than a
registry: a third audience is a one-line change, and nothing has asked to
register one from outside.

**Audience is immutable once a role exists**, since flipping it would
re-point every existing assignment at the other panel, and a non-staff role
may only hold keys its audience is granted — so `settings`/`staff`/`api_keys`
cannot reach a seller even through a hand-written seed.

## 2026-08-15: Country-derived store defaults are born from the merchant's answer, not seeded and rewritten

Amends the 2026-08-13 first-run setup entry. Damian's call, after
verifying against a live database that the setup endpoint's `country_code`
parameter silently did nothing.

**The seed can only guess a country, and the guess leaks.** Four seeds bake
`US`/USD in: the bootstrap market, the default stock location's country, the
Domestic/International delivery zones with their flat rates, and the pickup
method's calculator currency. Worse, `Store#default_country_code=` only
reaches the market through `after_create` — on a store that already has a
market it writes a dead column and `store.default_country_code` keeps
answering `US`, because the readers delegate to the market and the
`after_update` sync copies locale and currency only. So a merchant who
submitted `country_code: DE` at setup got a store still named "United
States", their own buyers routed to the International rate, and a domestic
flat rate priced in dollars.

**Decision: one provisioning service, two callers, seeds stop guessing.**
`Spree::Stores::ProvisionDefaults.call(store:, country:, locale:)` updates
the bootstrap market in place (the `sample_data/markets.rb` shape) and
creates the warehouse, zones, methods and pickup method in the right country
and currency; `Seeds::All` no longer runs `StockLocations`, `DeliveryZones`
or `PickupDelivery` (deleted, absorbed). The setup endpoint calls it inside
its store lock; `Seeds::AdminUser`'s env-credential branch calls it with
`STORE_COUNTRY`/`STORE_LOCALE` (defaults `US`/`en`), so CI, worktrees and e2e
are unchanged while scripted non-US installs stop being US-shaped.
Rewriting the seeded rows after the fact was the first sketch and was
rejected: every rewrite step that gets missed leaves stale "Domestic =
United States" data behind, whereas rows created from the answer cannot be
stale. A bare `db:seed` without credentials now yields a store with no
warehouse, zones or pickup until setup runs — correct, since nobody has said
where the shop is.

**Setup asks for country, locale and currency, each defaulted from the
country.** The countries gem gives currency and official languages per
country — the derivation `ensure_default_market` already used — so
`country_code` becomes required and both `locale` and `currency` default
from it. All three are editable: a first cut made currency read-only and
preselected English regardless of country, and both were wrong in the same
way — the form asked a question and then ignored the answer. Shipping from
Warsaw while pricing in euros, or running a Polish store in English, are
ordinary. Unknown `currency` is now a pre-token-spend 422 rather than
silently ignored. Locale options are the country's official languages
filtered to those Spree actually translates (Switzerland loses Romansh),
plus English; installs without spree_i18n skip the filter, since otherwise
every country would collapse to English. Country data comes from a new unauthenticated
`GET auth/setup/countries` guarded like the setup endpoint; folding it into
the status endpoint (polled by the login page) and a static SDK map (a
second source of truth) were both rejected.

**Sample data builds around the default market, never resets it.**
`sample_data/markets.rb` forced the default market back to US+CA/USD/en,
which would flip a German store to a US store on `spree:load_sample_data`;
it now reads what exists and creates the zones `fulfillment.rb` aborted
without.

Constraint for everyone: a store's country changes through its **market**,
never `Store#default_country_code=`; a new seed that depends on country or
currency goes into `ProvisionDefaults`, not `Seeds::All`; the service keeps
exactly two callers — wired to a settings page it becomes a data reset.

## 2026-08-14: ZoneRule retired by migration; Zone shelled to a migration-only reader

Two amendments to the 2026-08-12 jurisdiction-as-codes entry, both Damian's
call, finishing what "kept because it is persisted in the type column" left
hanging.

**`PriceRules::ZoneRule` is retired — onto MarketRule, with no replacement
class.** Markets are how pricing targets geography, so `spree:migrate_tax_zones`
converts each zone rule to a `MarketRule` where the zone's countries exactly
match one of the store's markets — the one mapping that provably keeps the
same buyers on the same prices. Where no market matches, the restriction is
unrepresentable: the price list is **deactivated**, the rule row removed, and
the task reports each list with the ISO codes it named so the merchant can
create the market and rebuild. Deactivating errs on buyers briefly losing a
discount over a restricted list quietly widening to everyone. A CountryRule
carrier class was written and then rejected the same day — it preserved data
at the cost of a second, half-alive geography concept beside markets.
ZoneRule survives as a bare STI shell (rows keep the old type until the task
runs; a 6.0 deployment boots before its upgrade tasks do), deleted in 6.1.

**`Spree::Zone` and `ZoneMember` are shells.** Bare ActiveRecord — the
associations plus a `country_list` — kept solely so the 5.6→6.0 upgrade tasks
(`migrate_tax_zones`, `migrate_zones_to_delivery_zones`,
`backfill_order_markets`) can read the rows they convert. Everything else
went: the matching/inclusion logic, seeds (`Seeds::Zones` and its EU_VAT
groupings — the markets sample data now names its ISO lists directly), the
permission-catalog entries, Country/State's zone associations, and Store's
`checkout_zone` bridge (deprecated since 5.4 with a 5.5 deadline, two
releases overdue). `6.0-delivery-zones.md` still owns dropping the classes
and tables in 6.1; what remains for it is deletion, not untangling.

## 2026-08-13: Stock leaves the shelf at fulfillment, not at order placement

Spree has always decremented `count_on_hand` when an order is placed, so a
warehouse's on-hand number in Spree never matched what a picker could count,
and the one event a warehouse cares about — the parcel leaving — wrote nothing
to the stock ledger at all. Typed Stock Movements splits the two: placement
writes an `allocated` movement that raises `allocated_count` and leaves
`count_on_hand` untouched, and dispatch writes a `shipped` movement that
decrements `count_on_hand` and retires the allocation with it. On-hand becomes what is on the shelf and
`StockLevel#allocated_count` carries what is promised, which is the model every
other commerce platform ships.

Three consequences worth naming, because they change existing behavior rather
than adding to it. Oversell is now `allocated_count > count_on_hand` instead of
a negative `count_on_hand` — the same signed arithmetic, so `backorder_limit`
and pre-orders are untouched, but `restock_backordered` and the movement's
`min_quantity` guard both existed only to service the negative representation
and are deleted with it. Availability must be read through
`Stock::Quantifier` / `available_count` everywhere, since a raw `count_on_hand`
read now offers units already promised to another customer. And allocation is
keyed to the **fulfillment**, not the line item: the fulfillment already owns
the origin location and the on-hand/backordered split, so allocating anywhere
else would re-decide what the Coordinator already decided.

Shipping only ever converts an allocation, which is also how the upgrade stays
safe: a fulfillment carrying no allocation is one created before the upgrade,
whose units already left under the old rules, so it ships without a movement
and its stock is never decremented twice. The manifest task reconciles the open
fulfillments it finds — on-hand and `allocated_count` move up together, leaving
availability unchanged by construction.

Plan: `6.0-typed-stock-movements.md` (phases reordered the same day: model
update before the data task, and the polymorphic `originator` drop held to 6.1
like every other 6.0 cleanup, since the task reads those columns). Consumers:
`6.0-stock-reservations.md` (the reservation term in the same formula),
`6.0-inventory-operations.md` (transfers, purchase orders, history screens).

## 2026-08-13: Document numbers — sequential by default, store-configurable orders, derived child numbers

`Spree::Core::NumberGenerator` (the boot-frozen `Module` factory) is replaced
at 6.0 by a `has_spree_number prefix: 'R'` macro (`Spree::HasNumber`, included
into `Spree::Base` so no model needs its own include) plus runtime-resolved
strategy classes
(`Spree.number_generators` registry, `NumberGenerators::Sequential` |
`::Random`). Sequential is the new default — invoice-like `R1001, R1002` with
a per-`(store, resource_type)` counter table (`spree_number_sequences`,
`with_lock` increment, portable across all three databases); random becomes
opt-in. Merchants get exactly one dashboard surface: an "Order numbers" card
(prefix, suffix, format, starting value — default 1001) stored as
`Spree::Store` preferences. Other document types keep code defaults;
developers swap generators via the registry.

The numbered-model census shrank. Numbers predate prefixed IDs as the
human-readable identifier, so each model was audited for who actually reads
its number: **Order** keeps the flagship stored number; **Return / Exchange /
Claim** keep stored numbers (customer-visible, dashboard cards, and the
`migrate_returns` resume cursor); **Fulfillment and Payment numbers become
derived methods** — stored value honored on legacy rows, new rows compute
`"#{order.number}-F1"` / `"-P1"` from parent + sibling position, generation
and counters gone (gateway `order_id` simplifies to `payment.number`;
idempotency to `"spree-#{payment.number}"`). Every other numbered model keeps
its stored number. The dividing line is *document handled outside the
dashboard* versus *row in an admin table* — which on inspection kept more
than the draft expected: transfer slips travel on boxes, POs are quoted to
suppliers, and **imports and exports mail their number in a subject line**
(`Your export EF1001 was successfully processed!`), so the planned removal of
back-office numbers was dropped during implementation.

Consequences: never parse or regex a `number` (format is merchant data now);
never write `spree_fulfillments.number` / `spree_payments.number` (frozen
until the 6.1 column drop); the global unique index stays, so sequential is
mostly-gapless and must never be sold as legal invoice numbering; settings
changes only affect future numbers; and code saving a numbered record with
`validate: false` must call `generate_number` itself, since the hook that
normally assigns one is `before_validation`. Plan:
`6.0-document-numbers.md`.

## 2026-08-13: Isolation tripwires — the guard under the store-scoping discipline

Open-core isolation is the controller discipline (every lookup through a
`current_store` association); row-level enforcement is deliberately not a
core feature. Two nets now sit under that discipline rather than trusting
review alone.

`Spree::StoreScopeGuard` wraps every v3 API request in development and test:
a SELECT against a store-owned table (schema-derived — any `spree_*` table
with a `store_id` column) carrying no `store_id` predicate is reported with
the SQL and call site. `log` by default, `raise` in this repo's API suite,
never active in production. Deliberately global lookups — the API-key
searches, where the key selects the store — opt out with
`StoreScopeGuard.skip`, which doubles as documentation of intent.
`watchable_environment?` is overridable so a multi-tenant enforcement layer
can run the guard as a production log-mode canary, and the schema-derived
watched set means tables stamped with `store_id` later are watched with no
registration.

Cache keys get a static audit spec: every `Rails.cache` call site in core
and api must visibly carry the store in its key or hold a reviewed allowlist
entry saying why the data is global. Writing the audit surfaced a real bug —
idempotency replay caching keyed per credential but not per store, so a
staff JWT reusing an Idempotency-Key across stores replayed the first
store's response. The key now partitions by the requested store.

Consequences: a store-less secondary-key lookup (slug, number, code, email,
token) or unscoped scan on a store-owned table inside an API request is a
test failure, not a review comment — wrap genuinely global lookups in
`skip`. Honest limits: id/foreign-key filters and `SELECT 1 AS one`
existence checks are exempt (they are dominated by loads from already-scoped
rows and uniqueness validations) — exemption is NOT proof of scoping, so a
lookup fed a request-derived id still requires `current_store` fetching even
though the guard stays silent on it; and only the v3 controller surface is
watched — jobs, webhooks and callbacks are a future extension, ideally keyed
off `Spree::Current.store` assignment rather than per-entry-point
registration. A new `Rails.cache` call without a store-scoped key fails the
core suite until scoped or reviewed onto the allowlist, and a store-owned
model with an unscoped `acts_as_list` fails it too (positions would bleed
across stores — the bug PaymentMethod shipped with, fixed alongside three
sibling leaks the tripwires surfaced: the pickup-location fallback, the
stock-location default flag, variant stock-item propagation, and data-feed
name uniqueness). Plan: `6.0-store-context-and-first-run-setup.md`.

## 2026-08-13: Store context is credential-derived — hostname resolution retired; first-run setup replaces the dummy admin

Every v3 API request resolved to `Spree::Store.default`: the configured finder
discarded the hostname it was handed, and no server code read the
`X-Spree-Store-Id` header the admin SDK sends on every request — so the
dashboard's store switcher silently lied, and API keys were validated
*against* the default store instead of *selecting* their own.

Decision: store context is explicit and comes from the credential, never the
hostname. The publishable key selects the store on the Store API (the key
already `belongs_to :store`); a secret key is bound to its store; JWT staff
sessions select via `X-Spree-Store-Id`, membership-checked against the
*requested* store (header-less JWT requests fall back to the default store
with a deprecation warning through 6.0, required at 6.1). Hostname-based
store resolution was a requirement of the server-rendered per-subdomain era
and is gone with it — never read `request.host` to pick a store.
`Spree.current_store_finder` stays as the override point.

With it, installation stops minting `spree@example.com` / `spree123`: the
seed creates an admin only when `ADMIN_EMAIL`/`ADMIN_PASSWORD` are explicitly
set, and otherwise a one-time, token-guarded first-run setup flow (dashboard
`/setup` + `auth/setup` endpoints, invitation-acceptance shape) creates the
first admin and adopts/renames the seeded store. The token is required in
every environment — no env-based security branches. No general store CRUD
ships in the OSS Admin API; first-run configures the one store.

Consequences: Admin API code must never assume `current_store` is the default
store, and store-touching cache keys must carry the store id by construction.
Plan: `6.0-store-context-and-first-run-setup.md`.
## 2026-08-12 — Code review findings on the payment surface, and what they corrected

The review of the day's work surfaced ten findings; all ten held up. The ones
that correct earlier entries in this log:

- **Profile creation had become dead code.** The after_save removal documented
  "creation flows call this explicitly" with no flow calling it. Now they do:
  `Payments::Create` profiles after its transaction, the admin payment
  endpoint after its lock (a source that cannot be profiled destroys the
  half-created payment, matching the old rollback), and specs that create
  payments programmatically call it themselves.
- **The webhook path settled with cold provider caches** — up to three Stripe
  round trips inside the order lock, contradicting settle_payment!'s own
  comment. `PaymentSession#prepare_for_settlement!` (no-op default; Stripe
  warms intent, charge and gateway customer) runs before HandleWebhook's
  lock, making the comment true.
- **capture! completed before splitting**, so a partial capture published
  payment.completed at the full amount. The split's row work now happens
  inside the lock before complete; only the remainder's authorize runs after.
- **settle_payment!'s completed? guard read a stale cached payment** — the
  same check-then-act shape one level down. Closed with a DB-state recheck
  inside the lock, not a reload (reload discards skip_source_requirement, as
  it discards card numbers in capture!).
- **The completion fence broke reads**: GET /carts/:id runs Checkout::Advance
  under with_order_lock and answered 409 for the claim window. The advance
  now skips claimed carts (`Cart#completion_claimed?`, which owns the TTL).
- Store scoping and correctness details: refund reasons resolve through
  `current_store.refund_reasons`; Stripe's cancel passes the store to
  order_canceled_reason; the customer payload sends ISO codes like the
  shipping payload; setup_intent.succeeded left SUPPORTED_EVENTS until core's
  webhook contract can route setup sessions.

## 2026-08-12 — Amount consistency during gateway operations: the completion claim, not a lock

Raised as a challenge to the lock removals: shouldn't the order be locked for
the whole gateway operation, so it cannot be mutated into a different total
than the one sent to the gateway? The invariant is right; the mechanism cannot
be. For session gateways the charge happens client-side before any server
endpoint runs — no server lock reaches it. And a row lock spanning a gateway
timeout pins a database connection per in-flight payment; a provider brownout
turns that into pool exhaustion for the whole store, not one order.

What actually enforces the invariant is Carts::Complete's three layers:
totals recalculated **inside** the cart's row lock at PREPARE ("not trusted
from earlier requests") and checked against the client's expected_total; the
`completing` claim stamped before the lock releases; payment coverage
re-verified at FINALIZE, with the Y3 undo popping payments back to the cart
when it fails.

The challenge found a real hole in layer two: the claim was only consulted by
guard_concurrent_completion — it blocked a second *completion*, but nothing
blocked a *mutation* during the unlocked gateway window. An AddItem landing
there changed the cart under a completion whose totals were fixed at PREPARE.
Now `with_order_lock` — the funnel every store cart mutation passes through —
refuses mutations while a fresh claim holds the cart (409
completion_in_progress), checked after acquiring the row lock so it cannot
race the claim being written, with the same TTL as the completion guard so a
crashed completion never bricks its cart.

**Consequences:** third-party gateway authors rely on four guarantees, none of
which is "the order is locked while you talk to your provider": the amount is
fixed in the session/intent and synced on update; mutations are excluded
during the completion window by the claim; completion re-verifies coverage
and compensates; settlement and capture bookkeeping serialize on row locks.

## 2026-08-12 — Payment lock audit: locks live where money is recorded, never around gateway I/O

A sweep of every payment operation with the settle_payment! lens — check-then-act
on money state without mutual exclusion — after the with_order_lock removals.
The rule that came out: **the row lock wraps the money bookkeeping with an
in-lock recheck; the gateway call runs before it, unlocked, relying on provider
idempotency.**

Two real bugs found and fixed:

- **`Payment#capture!` wrote the capture event before `handle_response`.** A
  concurrent second capture passed the completed? check, hit the gateway
  (idempotent at Stripe), persisted a second capture event, then exploded on
  `complete!` — doubled captured_amount plus an ungraceful error. Now: gateway
  first, then bookkeeping under `owner.with_lock` with a DB-state recheck
  (deliberately not a reload — card numbers never persist, and
  `split_uncaptured_amount` authorizes the remainder at the gateway, so it
  stays outside the lock). A declined response also no longer leaves a
  phantom capture event, and its failure transition runs outside the lock so
  the raise cannot roll it back.
- **Refund balance validation was unserialized.** Two concurrent partial
  refunds both validated against the pre-refund balance and both credited —
  a double-clicked 50% refund refunded 100% (Stripe's credit carries no
  idempotency key). The refund row is what reserves the balance
  (credit_allowed sums rows), so creation takes `payment.with_lock` in one
  place: `Refunds::Create`, which the returns/exchange/claim drain loops and
  Stripe's cancel verb all route through (code review caught the first
  version duplicating the lock/credit/compensation sequence at five sites —
  which also meant refund hooks and payment.refunded fired only for admin
  refunds). `perform!` stays outside the lock.

Judged acceptable, with reasons on record:

- **Double void** — no capture events involved; the second void gets the
  gateway's "already canceled" as a clean failure.
- **Concurrent `process_payments!`** — the gateway is deduped by the
  per-payment idempotency key, and the loser's `complete!` raises before its
  capture-event line, so money math survives; the error is ungraceful. An
  atomic claim (compare-and-swap on the state column) would make replays
  graceful — follow-up, not urgent.
- **Session create/update endpoints still hold with_order_lock across Stripe
  intent calls** — the same smell the confirm endpoint shed, but fixing it
  means restructuring gateway-owned code (persist the session row under a
  short lock after the intent call). Flagged as follow-up.

## 2026-08-12 — The payment lifecycle routes through its workflows; refund creation owns the credit

An audit found the two payment workflows were dead code: `Payments::Capture`
and `Payments::Refund` existed with hooks, but the admin API called
`payment.capture!` and `Refund.create` directly — inside `with_order_lock`, a
row lock held across gateway round trips — and `Refund#after_create :perform!`
fired the gateway credit from a save callback, the exact shape the workflow
doctrine prohibits. The boundary the plan says workflows own was owned by
controllers.

Five changes close the gap:

- **`Refunds::Create`** (renamed from `Payments::Refund`, key
  `refund_create_workflow`, before any release of the old key) owns refund
  creation end to end. The `after_create` is gone: the row commits, then the
  credit runs as an explicit `external_step` via a now-public
  `Refund#perform!` (idempotent — a present transaction_id is a no-op). A
  cleanly declined credit destroys the uncredited row, because
  `credit_allowed` sums every refund row and a dangling one would block the
  retry; a crash between commit and credit leaves the row for reconciliation.
  Returns, exchanges, claims and Stripe's cancel verb call `perform!`
  explicitly from their own external steps.
- **`Payments::Void`** exists (mirror of Capture) and the admin void endpoint
  routes through it; capture routes through `Payments::Capture`. Neither
  wraps in `with_order_lock` — replays are idempotent successes.
- **`PaymentSessions::Complete`** is the synchronous twin of `HandleWebhook`:
  same settlement through `settle_payment!`, plus the one veto point the sync
  path lacked (`validate` before money is recorded — the webhook path
  deliberately has none, money that moved cannot be rejected).
  `settle_payment!` itself takes the owner's row lock around the local
  settlement — the completed? guard alone is check-then-act, and two
  concurrent settlements would each record a capture event. The lock never
  spans gateway I/O (Stripe memoizes the intent and charge before settling;
  the webhook path's outer lock nests reentrantly), which is the difference
  between this and the controller-level with_order_lock it replaced.
- **`create_payment_profile` left its save callback and became an explicit
  call.** No subscriber replaced it — a first attempt proved why: the card
  number never persists, so profile creation only works on the in-memory
  instance the creation flow holds, and an observer that reloads the payment
  can never do it. Creation flows that take raw card data call
  `payment.create_payment_profile` after the commit; session gateways store
  profile ids during source creation and never call it. Row save alone no
  longer talks to a gateway.
- **`process_payments!` dropped its `with_lock`** around the gateway loop;
  re-entry is guarded by `started_processing!` and the per-payment gateway
  idempotency key.

**Consequences:** hook keys `refunds.create.*`, `payments.void.*` and
`payment_sessions.complete.*` are public API from 6.0. Controllers never wrap
gateway-calling workflows in `with_order_lock`. Anything creating a
`Spree::Refund` row must either call `Refund#perform!` from an external step
or accept an uncredited row — creation alone no longer moves money.

## 2026-08-12 — Providers never decorate core models; risk codes become a gateway interface

The Stripe provider shipped with three decorators on core models, and all three
are gone. A decorator is the extension mechanism of last resort — a first-party
provider using them licenses every third-party gateway to do the same, and a
`before_save` on `Spree::Payment` firing forever for one provider's bookkeeping
is exactly the shape that rots.

What replaced them decides the pattern for Adyen and every gateway after it:

- **AVS/CVV risk codes are a core interface.** The session flow never passes
  through the gateway response path that normally sets
  `avs_response`/`cvv_response_code` — the check results live on the payment
  source, in whatever shape the provider recorded them. Core now asks:
  `PaymentMethod#risk_codes_for(source)` (nil by default), called by `Payment`
  once at creation, response-path codes winning. Stripe's implementation
  translates its pass/fail/unchecked checks from the source's metadata. Core
  owns when to ask; the gateway owns how to answer. The old callback re-ran on
  every save; the hook runs at creation only — the sole lost case is a payment
  gaining a Stripe card source after creation, which nothing does.
- **Provider-scoped gateway customers are a core scope.**
  `GatewayCustomer.for_provider(SpreeStripe::Gateway)` replaces the decorated
  `.stripe` scope; every gateway needs exactly this filter.
- **The rest was dead or sugar.** The `.stripe`/`stripe?` payment-method
  decorator had no callers left. `store_accessor :metadata, :stripe_charge_id`
  was sugar over a hash write, so the service writes
  `payment.metadata['stripe_charge_id']` directly.

**Consequences:** the provider ships zero decorators and the engine's
`to_prepare` decorator glob is gone. A provider needing something from a core
model proposes a core interface, mirroring how delivery providers already work
(`Spree.delivery_rate_providers`, `Spree.fulfillment_providers`).

## 2026-08-13: Validate hooks are the validation extension surface; no generic model-validation registry

New plan `6.0-extendable-validations.md`. The question was whether developers
customizing validations — the single most common core-model modification —
deserve a generic add/remove validation mechanism, or whether workflow
`validate` hooks plus the existing model-level knobs already are the answer.
Decision: the latter. Adding a rule via prepended decorator is already short
and Rails-native; removing one via registry would require repackaging every
core validation as a named unit, and no competitor ships anything comparable.
Relaxing a core rule stays on named store preferences
(`disable_sku_validation` pattern) or predicate overrides.

What ships instead is the work that makes the hook recommendation honest:

- **`Carts::UpsertItems` graduates to the workflow tier** and absorbs every
  non-increment item mutation (bulk payloads, PATCH quantity, DELETE item —
  quantity `0` removes). It fires `validate` per item with `AddItem`-compatible
  readers, shares the item-application steps with `AddItem` (whose per-item
  full recalculate is what made N-item adds slow — the batch recalculates
  once), and is **partial-success on the storefront**: a per-item rejection
  skips the item onto the cart's existing `warnings` array on a 2xx response
  rather than rolling back the batch. The **order-side twin fails the whole
  batch** — a merchant's struck-out row silently not applying is worse than a
  failed request. No whole-batch veto in 6.0.
  `SetQuantity`/`RemoveLineItem` become deprecated shells.
- **`Products::Create`/`Update`/`Destroy` become workflows** (real
  orchestration, not the plain CRUD the doctrine rejects) with all write paths
  routed through them — Admin API v3, CSV importer, seeds — so hooks always
  fire. Variants ride the product graph; no standalone variant workflow.
- **Rejections carry `ActiveModel::Errors`.** `Workflow#errors` +
  argument-less `reject!` render through `render_validation_error`, so
  extension rejections share the model-422 shape (field-scoped symbolic
  codes) instead of a flat message under a controller-hardcoded wrong code.
  `reject!(message)` bridges to `:base`.
- **Address and cart creation get no workflow** — plain CRUD, demand already
  served (store preferences, gating predicates, `Spree.validators.addresses`
  which finally gets docs + a removal API + a `require_company` preference;
  flow-level address policy belongs on `carts.complete.validate`).
- **Custom-field value validation deferred** to its own plan: Shopify-style
  per-definition length/range/regex/allowed-values, enforced in the
  `CustomField` model, gating new writes only. The 2026-08-06 "required stays
  advisory" constraint is untouched.

## 2026-08-12: Jurisdiction is stored as a code, never as a country or state row

Amends 2026-08-06 ("Converted-away columns outlive the release that converts
them"), which had tax rates gaining `country_id`/`state_id`. They gain
`country_iso` and `state_code` instead — plain strings, upcased on write. The
reason is that `Spree::Country` and `Spree::State` are themselves on the way out,
so a rate pointing at their rows would need converting a second time; and "DE"
is what a merchant recognises, where a row id is not. It also matches the
jurisdiction snapshot `spree_tax_lines` already carries, so a rate and the line
it produced now speak in the same terms.

Everything else in that entry stands: `spree_tax_rates.zone_id` still survives
through 6.0 as `spree:migrate_tax_zones`'s input, and the task now writes codes.

**The cost, accepted:** the `state_belongs_to_country` validation is gone. With
codes there is no country row to check a state against, and keeping the guard
would mean keeping the `Spree::State` lookup this removes. A mismatched pair is
simply a rate that never matches an address — which is what the mismatch always
meant in practice, minus the early warning.

Because the columns had not shipped, the original migration was amended rather
than followed by a second one.

**Extended the same day to everything this work owns**, after a review pass found
the same shape elsewhere. `Spree::TaxExemptionCertificate` held country and state
references, and `Spree::PriceRules::ZoneRule` held a `country_ids` preference of
`Spree::Country` primary keys; both now hold codes (`country_iso`/`state_code`,
`country_isos`). The certificate case was a live defect rather than a tidy-up:
an unrecognised ISO resolved to a nil country, and nil claims *every* country
there, so a mistyped code silently turned one state's certificate into a
worldwide exemption. A code that matches nothing narrows to nothing.

`Spree::Pricing::Context` gained a `country_iso` reader so a price rule compares
codes rather than reaching through `context.country`; when Country goes, the
context is the only place that changes.

**Where a Country object is still correct:** `Purchase::Taxation#tax_country` and
`Spree::Current.tax_country` return one, and should. Those are lookups in request
context, not stored jurisdiction, and addresses and markets still speak in
countries. The rule this entry sets is about what a row *persists*.

## 2026-08-12: The label leads, fulfilled follows (amends the Phase 7 fulfill flow)

A warehouse prints the label, sticks it on the box, hands the box over — and
only then is the parcel fulfilled. The fulfill workflow used to invert that:
status flipped and the shipped email queued first, the label bought after,
which meant the merchant could not print a label without telling the customer
the parcel had shipped, the email raced the label purchase for its tracking
number, and a failed purchase surfaced only after the customer heard.

Two changes. `Fulfillments::PurchaseLabel` is the explicit pre-ship step:
buys the checkout-quoted rate through the provider, attaches tracking and the
label document, leaves the status untouched and sends nothing — and fails
loudly, because nothing has left the building yet. And `Fulfillments::Fulfill`
reordered its internals to split → buy label (external step) → mark fulfilled,
so the fulfilled event always sees the provider's tracking number; a label
failure there still degrades to "no label yet" per the provider doctrine,
since a carrier outage must never stop a merchant recording a parcel that
physically left.

Two contracts changed with it: providers must make `create_fulfillment`
idempotent (a label bought in the explicit step is returned, not re-bought,
when fulfill later runs), declared via `FulfillmentProvider.generates_labels?`;
and a failure after a partial-fulfillment split no longer rolls the split
back — a label may already be bought for the split parcel, and rolling the
parcel away would orphan a paid label. The split survives unfulfilled and a
retry picks it up.

Packing slips are the platform's document, not the carrier's — generated
client-side from data the order screen already holds, no prices, no admin
shell around them. Plan: `6.0-fulfillment-and-delivery.md`.

## 2026-08-11: One tracking number per fulfillment; multiple trackings deferred to 6.1

A fulfillment carries exactly one tracking number, one carrier and one carrier
lifecycle. When a shipment physically diverges into parcels, the answer is the
split flow the partial-fulfillment work already provides: each parcel becomes
its own fulfillment with its own items, status, tracking and `delivered_at`.
That is strictly more expressive than a list of tracking numbers on one
record — a bare list cannot say which items are in the box that bounced, and
delivery becomes all-or-nothing across the list.

What a separate tracking model would add is the narrower case: one logical
shipment in several boxes the merchant does not want to manage as separate
fulfillments (furniture in three cartons, a pallet of mixed packages).
Deferred to 6.1, deliberately after the carrier-axis work landed, because the
cost is now clear: `tracking_status`, `estimated_delivery_at`, `delivered_at`
and webhook matching all live on the fulfillment, and a
`spree_fulfillment_trackings` row would have to absorb that whole axis —
per-parcel carrier status, webhooks matched to a row, the fulfillment
delivered only when every row is — plus deprecation bridges for the
fulfillment-level columns that are public API since 6.0.

Design constraint recorded for whoever builds it: the tracking row takes the
entire carrier axis with it. Splitting the axis across fulfillment and
tracking rows — status here, delivered_at there — recreates the two-sources
problem the 6.0 status rework just removed.
Plan: `6.0-fulfillment-and-delivery.md` (Phase 6, resolved question 15).

## 2026-08-11: Fulfillment status model — two axes, `delivered` first-class, machine removed (supersedes part of 2026-08-10)

`Fulfillment#status` collapses to `unfulfilled → fulfilled → delivered` plus
`canceled`, plain string via `HasStatus`, state machine deleted. `pending` and
`ready` were payment and stock facts wearing a fulfillment costume —
`determine_state` re-derived them from `order.paid?` on every recalculation, so
a refund flipped a fulfillment's status with no physical change, and merchants
never understood them. That gating becomes a validate guard in
`Fulfillments::Fulfill` (rejects with a reason, staff-overridable).
`ready_for_pickup` dies as a status: pickup `fulfilled` means "ready at the
counter", `delivered` means picked up, presentation is modality-aware.

`delivered` is the new terminal state — confirmed receipt, the thing merchants
kept asking for (the lifecycle used to end at handover). Set by carrier
tracking, a staff button, or later customer confirmation, via
`Fulfillments::MarkDelivered` (`delivered_at`, `fulfillment.delivered` event).
The returns eligibility window and the EU 14-day withdrawal period anchor on
`delivered_at`.

Carrier truth is a second axis, data not a machine: `tracking_status` +
`tracking_details` + `estimated_delivery_at`, overwritten per update
(`pre_transit … delivered, return_to_sender, failure`), written by
`Fulfillments::UpdateTracking`. Bounces and failed attempts surface there
without mutating `status`. The EasyPost gem feeds it from tracker webhooks —
every purchased label already has a tracker whose updates were being thrown
away; trackers for hand-entered numbers cost money each, so opt-in.

This supersedes the 2026-08-10 "the dangerous callbacks move, the machine
stays" conclusion: with `pending`/`ready` gone the machine held two transitions
and its event publishes, which is what `HasStatus` + workflows already do for
Return/Exchange/Claim. The side-effect relocation stands and made removal
cheap. The FulfillmentItem machine and the other machines (Payment,
ReturnAuthorization, GiftCard) are unaffected. Status mapping for existing
rows: `pending|ready → unfulfilled`, `ready_for_pickup → fulfilled`,
pickup-modality `fulfilled → delivered`, shipping-modality `fulfilled` stays.
Plan: `6.0-fulfillment-and-delivery.md` (Key Decisions → "Status model — two
axes", Resolved Question 14, Phase 7).

## 2026-08-11: The order edit screen stages edits and saves in bulk (reverses 2026-08-10)

The 6.0 admin order edit screen was specified to write immediately — one
interaction, one request — and shipped that way: a dialog per quantity change, a
confirm dialog per removal. That is the wrong shape for an order editor and the
constraint behind it was wrong.

It now works as a form. Quantities are inputs, a row's `x` marks it removed
(struck through, reversible), Save applies the batch and Discard drops it.

**Why the original constraint was wrong.** It existed to forbid a *persisted*
per-domain draft: a shadow order in the database that
`6.1-order-change-substrate.md` Phase 3 would have to migrate onto `OrderChange`.
That reasoning holds. But it was extended to cover transient React form state,
which is a different thing entirely — a form holding "quantity 2 -> 3, line 4
removed" until submit persists nothing, so there is nothing to unpick later. It
is the same dirty-tracked form pattern the dashboard uses everywhere else.

**Staged edits fit the substrate better, not worse.** `OrderChange` is
`begin -> request -> confirm -> cancel`: accumulate actions, then confirm. A
screen that already batches behind Save maps onto that directly, and Phase 3
becomes additive (a totals delta, `begin` on entry). The immediate-write version
is the one that would have needed reshaping, having no confirm moment at all.

**Immediate writes were also worse on their own terms.** Every keystroke in a
quantity field fired a request and re-summed the order server-side, and removing
a line was irreversible with only a confirm dialog in the way. Staging gives the
merchant a Discard.

**Accepted limitation.** There is no bulk line-item endpoint, so Save issues N
calls against the existing per-item routes and a mid-batch failure leaves
earlier writes applied. The screen reports what succeeded and keeps the rest
staged. Deliberately not fixed with a new bulk endpoint: Phase 3's
`OrderChanges::Confirm` applies every action in one transaction, so building one
now would be work thrown away.

**What stays forbidden:** persisting pending edits in any schema, and computing
a projected total client-side to fake a preview — 6.0 cannot project totals, and
an approximation would disagree with the server.

## 2026-08-11: Cross-border tax-inclusive pricing derives net-fixed, except where the merchant priced that geography

A live pass against a running server found three defects in one seam — what a customer is charged
when the destination's VAT rate differs from the home zone's. `6.0-tax-provider.md` gains Phase 8 to
fix them (the 6.1 cleanup renumbers to Phase 9).

**The rule, which is Shopify's:** a price the merchant set for a geography is **final** — charged
exactly as entered, never restated. Everything else **derives net-fixed**: home rate out, destination
rate on, via `VatPriceCalculation`. The merchant's net is preserved and the gross moves.

"Set for a geography" needs the `match_policy`, not just the presence of a geographic rule
(`MarketRule`, `ZoneRule`), because a list can win without its geographic rule being the reason:

- `match_policy: 'all'` — every rule matched, so the geography is why this price applied. **Final.**
- `match_policy: 'any'` — the list may have won on a non-geographic rule alone (a volume break, a
  customer group), so the price is not evidence of a decision about this destination. Final only
  when *every* rule is geographic.

Each rule kind answers `geographic?` for itself, always a boolean; the base `PriceRule` answers
false, so a rule that names no geography — including an empty country or market list, which matches
every buyer — never makes a price final.

**Why this matters beyond tax.** Two of the three defects are pricing defects, not tax defects:

1. `Pricing::Context.from_order` never carried the owner's `market`, so cart line pricing followed
   the request's `x-spree-country` hint (or the store default) instead of the cart's own market.
   Measured: a catalogue request with the hint served a French price list at 99.00 while the cart on
   that same French market priced at 100.00, and the wrong figure persisted. **Market-scoped price
   lists were therefore unreachable from a cart** — they work for the catalogue only.
2. `Cart#recalculate_for_address_change!` called `LineItem#update_price`, which assigns without
   saving, where `recalculate_price` persists. A destination change computed the restated price and
   discarded it; a later quantity change wrote it. So what a cross-border customer paid depended on
   the order of operations.

**Constraints this places on other work:** cart-stage pricing must read the cart's own market, never
`Spree::Current` (catalogue requests keep that fallback, having no owner); any new `PriceRule`
subclass must answer `geographic?`, since that predicate now decides whether its list's prices are
exempt from restatement; and re-pricing paths must stay behind
`Carts::Complete#verify_expected_total`, whose `cart_changed` failure is what makes a mid-checkout
price movement disclosable instead of silent.

**Restatement is a capability of the Internal provider, not of the platform.** `VatPriceCalculation`
derives both the home and destination rate from `TaxRate` rows, so it only works where those rows are
the whole truth. An absent row is ambiguous — *no tax is due here* or *tax is computed by an engine* —
and the code reads it as the former. Measured: German home zone, Japanese destination, no Japanese
rates, and 100.00 is charged as **84.03**. Correct for a genuine zero-rated export; wrong for a market
whose engine simply has no rows in that table, where it makes every foreign destination look like an
export. So restatement runs for Internal and is skipped elsewhere, with a geo-scoped price list as the
external-provider merchant's way to state destination prices. Shopify arrived at the same separation:
dynamic tax-inclusive pricing reads a standard-rate table and is explicitly unsupported alongside
AvaTax. A
read-only `rate_for` on the provider contract would dissolve the limitation and stays deferred with
the delivery-option quote question, which is the same problem for a different surface.

Surveyed for this: Shopify, WooCommerce, Magento/Adobe Commerce, BigCommerce, Saleor, Medusa,
Vendure, commercetools. Net-fixed is the majority default (WooCommerce, Magento, Shopify, Vendure);
the headless platforms (Saleor, commercetools, Medusa) refuse to derive at all and require a price
per channel/region.
## 2026-08-10: Fulfillment side effects move to workflows; the state machine keeps the status column

Answers "should Fulfillment follow Order and lose its state machine?" with
**partly, deliberately**. The side effects move; the machine stays.

`Fulfillment#after_cancel` restocked every unit **and** called
`provider.cancel_fulfillment` — network I/O (an EasyPost label refund, a 3PL
stand-down) running inside the save transaction that held the stock movements.
That is precisely the failure `6.0-service-workflows.md` cites as the reason
transition callbacks are the wrong place for side effects: a slow carrier holds
row locks, and a failing one rolls back a restock that already happened at the
warehouse.

`Spree::Fulfillments::Cancel` and `::Resume` now own that work — restock and
status inside one transaction, the provider call as an `external_step` after it
commits. `Fulfillments::Fulfill` (added the same day for partial shipments)
gained an explicit unstock for the `canceled -> fulfilled` path the resume
callback used to cover; missing it would have shipped goods without taking them
off the shelf.

**What the machine keeps:** the status column, the transition graph and its
guards, and the `publish_*_event` callbacks. Publishing an event *describes* the
status change rather than being a side effect of it, so it belongs where the
transition is. The graph is real validation work — the narrow exception
`6.0-service-workflows.md` already allows.

**Why not remove the machine outright.** Four other models still carry machines
(Payment, InventoryUnit, ReturnAuthorization, GiftCard). Removing one at a time
means re-litigating the same design in five separate rounds, and Fulfillment's
`ready`/`resume` guards are conditional on `determine_state`, so replacing them
is not mechanical. A full removal is a planned wave with its own document, not a
refactor folded into fulfillment UI work. This also amends
`6.0-fulfillment-and-delivery.md` resolved question 1, which had promised all
transition hooks were preserved.

**Composition constraint, and the wrong turn taken first.** `Orders::Cancel`
and `Orders::Resume` cancel or resume every fulfillment from inside the order's
own transaction, and a nested `external_step` raises `ContractError` by design.
The first attempt worked around this by putting the restock bodies on the model
as public `#restock_units`/`#unstock_units` and having both layers call them.
That was wrong twice over: it violates the rule that workflows write behavior
inline as named steps rather than delegating to model business methods, and it
plants new public model surface that would have to be torn out again when the
machine is eventually removed — the opposite of the direction the model is
moving.

The right shape: the stock movements are written inline in the workflow steps,
and `Fulfillments::Cancel` takes a `notify_provider:` flag so a caller that
already holds a transaction can suppress the external step and batch the
carrier calls into its own. `Orders::Cancel` passes `notify_provider: false`
and notifies after commit; `Orders::Resume` nests cleanly because Resume has no
external step. **The general rule: when a workflow with an `external_step` must
run inside another's transaction, give it a flag to defer the external half —
do not push the shared behavior down onto the model.**

## 2026-08-10: Order editing splits from fulfillment management; two OrderChange questions resolved

The 6.0 admin order detail page grows a **separate edit screen** at
`/orders/$orderId/edit` owning post-placement line-item mutation — add, remove,
change quantity. The order detail page keeps fulfillment management (what ships,
from where, under which delivery method); it no longer offers line-item editing.
The split follows the reference layout and, more importantly, matches how
`6.1-order-change-substrate.md` Phase 3 wants to wrap the edit surface in a
change set without disturbing fulfillment UI.

The 6.0 screen **writes immediately and shows no totals delta**. Projecting
totals without writing rows is impossible before the OrderChange substrate
lands, and the alternative — buffering edits in React state so the UI can fake a
preview — is a per-domain draft living in the browser, which the substrate plan
explicitly forbids. The money math still goes through a value-object-returning
service so Phase 3 re-points it at `OrderChanges::Preview` without touching
callers.

Two of that plan's open questions are settled as a consequence:

*A change set belongs to one `Order`, never to an `OrderGroup`.* Multi-vendor
fans a cart into N child orders under one group, and the marketplace plan's
Decision 8 keeps line items, fulfillments and totals on the children — the group
holds only customer, payment and addresses. Change sets mutate child-owned rows,
so they bind to the child. Cross-vendor edits are N change sets, which is also
where the money belongs: each vendor settles against its own order.

*A pending change set does not hold stock.* Stock reservations are scoped to
checkout — held against a cart, extended by customer activity, expired by a job.
An admin editing a placed order is neither, so reusing that machinery would
create reservations with no expiry trigger. `add_item` takes stock at confirm,
and confirm is where an out-of-stock action fails.

Also settled for the backend: **partial fulfillment ships as a
`Spree::Fulfillments::Fulfill` workflow**, not by extending the state machine.
`Spree::Fulfillment` keeps its machine (preserved deliberately per
`6.0-fulfillment-and-delivery.md` resolved question 1), but shipping a *subset*
means splitting first, and split-then-ship inside an `after_transition` callback
is exactly the shape `6.0-service-workflows.md` prohibits. The workflow wraps the
machine as a low-level mechanic, mirroring how `Fulfillments::Create` already
wraps `mark_shipped`.
## 2026-08-10 — One payment settlement path: PaymentSession#settle_payment!

A settled payment session is noticed on two routes — the storefront's confirm
call and the gateway webhook — and they settled the payment differently. The
webhook path called `Payment#confirm!`, a local state move guessed from the
`auto_capture?` setting. The Stripe sync path called `process!`/`authorize!`,
which route through `gateway_action` back into the gateway's authorize/purchase
verbs: a second Stripe round trip to learn what `complete_payment_session` had
just read from the intent. Worse, those verbs look the owner up in
`store.orders`, which can never find a cart — so checkout-time (cart-owned)
settlement failed with "Order not found". The specs missed it because they
built order-owned sessions.

Now both routes call `PaymentSession#settle_payment!(captured:)` — find or
create the payment, skip if completed, then `confirm!(captured:)`. The
`captured` flag carries what the gateway actually reported instead of the
config guess: `Payment#confirm!` gained the keyword (nil keeps the old
auto_capture fallback for any other caller). Stripe passes intent status
`succeeded`; the webhook path passes `action == :captured`. That also fixes the
dashboard-capture edge: a manual-capture payment captured directly in the
Stripe dashboard now completes on webhook instead of pending forever.

**Consequences:** gateway `complete_payment_session` implementations settle via
`settle_payment!` and never call `process!`/`authorize!` — those verbs remain
core's fallback for payments not covered at completion time, where the owner is
already an Order. A gateway reports facts (`captured` or not); core owns what
the payment does with them.

## 2026-08-10 — Stripe drops Apple Pay domain registration; payment intents are not a subsystem

Two removals from the Stripe port, both from the same question: what does a
headless backend actually know?

**Apple Pay / Google Pay domain registration is gone.** The gateway registered
`store.url` with Stripe on create, and re-registered whenever a store code or
custom domain changed. That only works when Spree serves the storefront. Headless,
the storefront is someone else's deployment on a domain the backend never sees,
so the call registers the wrong host — worse than not running, because it looks
like it worked. Merchants register domains in the Stripe dashboard, which is
where a headless setup has to do it regardless. Removes `RegisterDomain`, its
job, the `CustomDomain` decorator and the `stripe_apple_pay_domain_id` /
`stripe_top_level_domain_id` accessors.

**Payment intents are not a parallel system.** A `Gateway::PaymentIntents`
concern alongside `Gateway::PaymentSessions` implied two paths, one of them
legacy. There is one: creating a payment session *is* creating a Stripe payment
intent, and the session stores the intent id as its external id. The intent
calls now live in `Gateway::PaymentSessions`, with payload building private to
it. `PaymentIntentPresenter` went too — it presented nothing, it built a request
body, and `update_payment_intent` proved the framing wrong by constructing the
full create-payload only to `slice` most of it away.

**Consequences:** the gem no longer touches storefront domains at all, and there
is no "intents" vocabulary suggesting a second code path. Net −2,000 lines
against the initial port. A gateway that wants to register domains needs the
storefront's real host as configuration, not `store.url`.

## 2026-08-09 — Stripe moves into the monorepo as a payment-session-only gem, with no tables

`spree_stripe` ships from `spree/providers/stripe` in the monorepo, per
`6.0-payment-gateways-monorepo.md`. Three things were decided during the port
that the plan had left open or assumed differently.

**Scope is the payment-session API, not the whole gateway.** The plan's
keep-set was "the v3 half of the repo"; the sharper line is the session flow.
The six money verbs (`authorize`/`purchase`/`capture`/`credit`/`void`/`cancel`)
stay, because core's payment lifecycle calls them after a session completes —
`Spree::Gateway::Bogus`, core's own reference session gateway, implements the
same six. What left is the machinery around them: creating intents for payments
that never had a session, off-session confirmation, the storefront
redirect/confirm controllers, `SpreeStripe::CompleteOrder` (`Carts::Complete`
owns completion now), and the `stripe_event` engine with its four webhook
handlers — webhooks arrive at core's v3 endpoint and route through
`#parse_webhook_event`. Stripe Tax is dropped outright and revisits as a
`TaxProvider`.

**The webhook-key tables collapse into preferences, and the gem ends up with no
schema at all.** `spree_stripe_webhook_keys` plus its join table existed to map
signing secrets to payment methods many-to-many — a shape that only made sense
while a payment method could be shared across stores. `belongs_to :store` means
one endpoint per gateway, so the secret is a `:password` preference. Worth
stating plainly, because the plan called this an "encrypted preferences" move
and it is not: `spree_payment_methods.preferences` is serialized YAML with no
encryption at rest, while the dropped model declared
`encrypts … deterministic: true`. It is not a new exposure — the Stripe secret
key, a more powerful credential, has always sat in that same column — but
encrypting the preferences column is now a live core-wide question rather than
something this port solved. `spree:upgrade:migrate_stripe_webhook_keys` carries
existing secrets across.

**Manifest steps from optional gems need an `optional: true` flag.** The
upgrade runner resolves each step with `Rake::Task[…]`, which raises when the
task isn't defined — so an unconditional Stripe step in core's 5.6→6.0 manifest
would break `rake spree:upgrade` for every install without the gem. The flag
makes the runner skip with a note. Every future gateway gem contributing a
backfill uses it.

**Consequences:** gateway configuration lives in payment-method preferences,
never in new tables — a gateway that thinks it needs one should first check
whether single-store ownership removed the reason. Gem-contributed upgrade
steps are always `optional: true`. Two committed VCR cassettes were found
carrying real webhook signing secrets (the sensitive-data filters covered
request keys but not response bodies) and were redacted; cassettes now default
to `record: :none`, since record-by-default turns renaming a `:vcr` example
into a live API call.

## 2026-08-09: Metadata consolidated to one column — `public_metadata` dropped, `private_metadata` renamed

Implements the 2026-03-16 consolidation decision. All thirty metadata-carrying
tables lose `public_metadata` and have `private_metadata` renamed to `metadata`,
so the column, the accessor and the API field finally share one name.
`Spree::Metadata` keeps its place but collapses to a single attribute plus the
`HashSerializer` — the alias indirection that made `metadata` a method forwarding
to another column is gone. `Spree::Collection`, which had been declaring its own
consolidated column to sidestep the concern, now just includes it.

**Three shape decisions.**

*`public_metadata` data is preserved, not discarded.* The original note called the
column unused, which holds for Spree's own code — nothing read it, and it was
never exposed in the Store API — but is not provably true of host applications
that had a writable JSON column sitting there for four years. A dropped column has
no rollback, so `spree:upgrade:consolidate_metadata` merges it into
`private_metadata` first, private winning on key collision since that is the side
the accessor and the API always read.

*The merge lives inside the migration, not in a manifest step.* The obvious home
was a pre-migration upgrade task, but `spree:upgrade` runs manifests *after*
`db:migrate` — both the rake runner and the CLI's upgrade command sequence it that
way. A merge scheduled there would find `public_metadata` already dropped and
silently do nothing, losing exactly the data it existed to protect. Documentation
telling operators to run a step "before migrate" would have been asking them to
fight their own tooling. `spree:upgrade:consolidate_metadata` stays in the manifest
as a safety net for schemas changed out of band, not as the primary path.

*The rename is `rename_column`, not add-and-backfill.* Instant on PostgreSQL and
MySQL, data stays in place.

*No hardcoded table lists, in either direction.* Legacy tables are discovered by
column: the pair was added across a dozen migrations and several of those tables have
since been renamed (`spree_shipping_methods`, `spree_prototypes`, `spree_taxons`), so
a static list would already be wrong. Rollback needs the inverse answer, and shape
cannot supply it — a table we renamed and one born with a single `metadata` column look
identical afterwards. An early version hardcoded the exclusions and was doubly wrong:
it missed `spree_customers`, and it would have swept up `active_storage_blobs`, whose
unrelated `metadata` column a shape-based rollback would have renamed, breaking every
attachment. `up` now records what it renames and `down` reverses exactly that.

Both the migration and the task use raw SQL rather than Active Record. Beyond the
models already pointing at the new name, PostgreSQL has no equality operator for
`json`, so `where.not(public_metadata: [nil, {}])` raises `PG::UndefinedFunction` —
green on SQLite, broken on the databases most production installs actually run.

**No bridge for `public_metadata`** — a recorded exception to the "every 6.0 rename
keeps the legacy name one release" convention. The column is being removed rather
than renamed, and it already carried a deprecation warning through 5.x.
`private_metadata` does get the usual one-release bridge with a warning.

**What this does not change.** Metadata and metafields stay two systems. Metadata
is the schemaless developer escape hatch — no definition, write-only from the
Store API's perspective, for integration ids and sync state. Metafields (custom
fields) stay merchant-defined structured data with types, definitions and
storefront visibility. Customer-visible structured data belongs in a metafield,
never in metadata.

Plan: `docs/plans/6.0-consolidate-metadata-columns.md`.

## 2026-08-07: The tax plan builds the minimal Company tree; the B2B release keeps Catalog

Exemption certificates need an entity to hang off, and `Spree::Company` does not
exist — `6.1-channels-catalogs-b2b.md` targets 6.1. Rather than leave the tax
plan's last phase blocked behind a release, `6.0-tax-provider.md` Phase 7 builds
**Company → CompanyLocation → CompanyContact** plus
`Spree::TaxExemptionCertificate`, and the B2B release inherits those models
instead of defining them.

**Why the whole tree and not just Company.** The contact record is what lets a
logged-in B2B buyer's own cart resolve a company without staff touching the
order. Company alone would mean exemption works only on admin-created orders —
the wrong limitation for a self-serve wholesale channel. The location is what
the Cart and Order reference (`company_location_id` on both, following
`channel_id`/`market_id`), because that is the FK the B2B plan already specifies
for orders; a direct `company_id` would save one hop now and cost a schema
reversal later.

**Supersedes the B2B plan on one point: no `tax_exempt` boolean.** That plan's
Company and CompanyLocation sketches both carry one. It is not being built. A
flag cannot say which jurisdiction it holds in or which lines it covers, and
removing the boolean `exempt?` from the provider contract was the substance of
the 2026-08-05 refinement — reintroducing it a layer down would undo it.
Exemption is a certificate resolved into a typed `Spree::TaxExemption` entry.
**`6.1-channels-catalogs-b2b.md` still needs this note added to its own Key
Decisions** — deliberately not edited yet, at the author's instruction.

**Explicitly not pulled forward:** Catalog, CatalogProduct, CatalogAssignment,
`default_catalog_id`, per-company pricing, `Products::ForContext` visibility, the
Company → CustomerGroup link, and roles/approvals/purchase limits/invoicing.
Certificates hang off Company scoped by their own country/state columns, so no
per-location duplication.

**Constraint going forward:** pulling a model forward out of another plan takes
the model, not the feature. If a field only makes sense for the deferred feature,
it waits with it.

## 2026-08-07: The pricing zone dimension ships with the tax provider, but the price-rule design stays with delivery-zones

`6.0-delivery-zones.md`'s ownership table gives the `Pricing::Context` zone
dimension and the `Spree::Current` zone attribute to that plan, "with
tax-provider". It landed in the tax provider work instead, because the two
cannot be separated: `Pricing::Context.from_order` read `order.tax_zone`, so it
broke the moment `Purchase::Taxation#tax_zone` was removed — which the same
table assigns to the tax plan.

`Spree::Current.tax_country` returns a `Spree::Country` rather than the ISO
string that plan's constraints section specified, matching the already-shipped
`Purchase::Taxation#tax_country`. An ISO code would mean a country lookup on
every read, and the price rule compares stored ids.

**Where the line was drawn.** `PriceRules::ZoneRule` also reads the zone
dimension, so it had to change or crash. It now decides by country, keeps its
class name (the `type` column persists it), stays out of the rule registry, and
`spree:migrate_tax_zones` restates each row's stored zones as the countries they
contained — state-level zones widen to the whole country, which the task
reports. What was **not** done: promoting it to a first-class `CountryRule` with
a factory and a registry entry. That is a customer-visible pricing feature no
plan called for, and it belongs to the plan that owns Zone's removal.

**Constraint going forward:** "something must change or it crashes" licenses the
minimum that keeps it working, not a redesign. When a forced edit reaches into
another plan's surface, do the minimum and hand the design decision back in that
plan's own document.

**Corollary (2026-08-07).** The same reasoning ruled out guarding the window
between `db:migrate` and the data task. A review found that an unconverted rule
matches every country, and the first fix made such a row refuse to apply. That
was also scope creep: the 6.0 data tasks are steps in the upgrade manifest, so
"code deployed, task not yet run" is not a state Spree supports, and inventing
behaviour for it adds a permanent branch to a hot path to cover a transient.
Don't design for half-upgraded installs; make the task correct and say what it
did.
## 2026-08-09: Origin groups and per-currency delivery pricing in 6.0

Two same-day additions to the delivery-profiles model, both Damian-approved
mid-review of PR #14404.

**`Spree::DeliveryOriginGroup` (pulled forward from the 6.1 open
question).** Zones are per-profile (the profile-based platforms' shape;
sharing across profiles was considered and rejected — editing a shared zone
would silently change other profiles' coverage). Within a profile, origin
groups partition the fulfillment origins: every zone and method belongs to
one group, so "same products, different warehouse, different rates" is one
profile with two groups instead of hand-narrowed method duplicates. The
auto-created nameless default group (no members = all locations) keeps the
layer invisible for single-origin stores. The profile ↔ stock-location join
is replaced by group membership (profile coverage = union of its groups);
per-method ships-from narrowing retires for shipping methods, and
`DeliveryMethodStockLocation` stays pickup-only (collection counters).
Admin API: nested origin_groups CRUD under delivery_profiles; the
profile-level `stock_location_ids` shorthand reads/writes the default
group.

**Per-currency delivery pricing (kills method-per-currency).** Amount-based
shipping calculators (FlatRate, PerItem, DigitalDelivery) gain an `amounts`
hash — one explicit amount per currency, no FX, mirroring product prices;
a currency without an amount hides the method for those carts. The legacy
single `amount`+`currency` pair stays as the fallback for its own currency,
so upgraded 5.x stores quote unchanged. Percent calculators are
currency-agnostic and drop the currency gate; PriceSack/FlexiRate keep
strict single-currency matching. The Estimator consults
`calculator.supports_currency?` instead of exact-matching the currency
preference. Carrier quotes: `DeliveryRateProvider::Estimate` gains
`currency`, EasyPost passes the carrier's `rate.currency` through, and the
Estimator drops estimates quoted in another currency than the cart's — a
number in the wrong currency must never reach checkout (EasyPost has no
quote-currency parameter; multi-currency carrier setups use
per-currency carrier accounts). The pricing card renders one amount per
supported store currency; the default currency maps to the legacy amount
preference.

## 2026-08-09: Fulfillment profiles — ShippingCategory promoted, not removed

Reverses three recorded decisions inside the 6.0 window: "fulfillment types
are NOT a model", "named delivery groups are the 6.1-if-needed successor to
profiles" (both `6.0-fulfillment-and-delivery.md`), and live-by-reference
`fulfillment_types` on ProductType (`6.0-product-types.md`). Full design in
`6.0-delivery-profiles.md`.

**The model.** `Spree::DeliveryProfile` — store-scoped STI, one default
per store, kinds registered via `Spree.delivery_profile_types`
(`DeliveryProfiles::Shipping` default, `::Digital`) — groups products
for delivery: profile ↔ stock locations (origins, empty = all), profile →
delivery zones (destinations), profile → delivery methods (each with an
optional single zone and optional ships-from narrowing via the generalized
method↔location join). Products carry `delivery_profile_id` directly;
ProductType stamps its template profile at creation and never manages it
afterwards. Carts split per profile. **Classes only, no string
vocabularies (refined same day):** the method's `fulfillment_type` column
is dropped (not renamed to modality), `Spree.fulfillment_types` and the
ProductType array are deleted; behavior routes through class predicates —
`FulfillmentProvider` subclasses answer `digital?`/`pickup?`/
`pickup_point?`/`requires_address?`, rate providers declare
`requires_address?` instead of type lists, and the profile kind declares
`digital?`/`requires_shipping_address?` and validates composition (a
Digital profile accepts only digital-provider methods; a carrier rate
provider only prices methods that ship to an address). A location-group
layer was considered and dropped — per-method narrowing covers
multi-origin stores, and groups can arrive additively later.

**Why reverse now.** No rewrite window after 6.0; custom string types were
second-class (provider declarations could never include them, so a custom
type could not use carrier rate providers); the origin axis simply did not
exist for shipping methods; and the fulfillment_types array was the sole
live-by-reference exception to the product-type template doctrine.

**Migration by rename.** `spree_shipping_categories` →
`spree_delivery_profiles` and `spree_products.shipping_category_id` →
`delivery_profile_id`: 5.x products arrive assigned, the 5.x Digital
category becomes the Digital profile. `spree:migrate_delivery_profiles`
(5.6→6.0 manifest) handles what a rename cannot: store assignment for the
formerly-global categories (duplicate + remap when shared), folding
non-narrowing categories into the store default profile, digital-kind
detection, and collapsing the method m:n
(`spree_shipping_method_categories`, kept to 6.1 as source) into the
single method FK — loud warnings wherever flattening loses information.


## 2026-08-09: Dynamic carrier rates — one delivery method, many named rates

Supersedes the one-rate-per-method model in `6.0-delivery-rate-provider.md`
(its unique-index gate is hereby exercised): a carrier-backed DeliveryMethod
is the carrier connection, `DeliveryRateProvider::Base#estimates(package)`
returns one Estimate per service, and every service becomes its own named
`DeliveryRate` at checkout ("UPS Ground", "USPS Priority Mail"). This also
finally delivers the "one Carrier shipping method per market, the provider
returns whatever serves the address" aspiration recorded in the 2026-07-29
aggregator survey, which the previous schema could not.

**Merchant controls** (Shopify's knob set plus label overrides, which
Shopify lacks): a new `Spree::DeliveryMethodService` row model — one row per
carrier service, unique on (method, carrier, service) — narrows which
services are offered (no rows = everything, current and future) and carries
per-service `label`, `markup_flat`, `markup_percent`; method-level markup
columns are the fallback. Rows, not preferences: independent per-service
controls need a real model with real validation and API round-tripping.

**Consequences.** `spree_delivery_rates` lost its unique
(fulfillment, delivery_method) index and gained `name` (nil for calculator
rates — `DeliveryRate#name` falls back to the method name, preserving the
old delegate behavior). Selection across re-quotes and EasyPost label
purchase key off the selected rate's carrier/service, not method config.
The EasyPost method-metadata carrier/service binding is deleted. Seeds and
sample data reshaped Shopify-style: Domestic + International delivery zones
per store with basic flat-rate methods, replacing the continental sprawl.

**Competitive grounding** (researched 2026-08-09): Shopify persists service
selection + handling fee on the zone's carrier-rate entry and quotes live
(labels not renamable); Medusa materializes one ShippingOption per service
from the provider catalog; Saleor delegates everything to apps; Vendure is
one-method-one-quote. The two-entity method→services shape is the
normalized version of what Shopify/Woo store as config blobs, and Spree
ends up expressing all four models.

## 2026-08-07: Country/State AR models dropped — ISO codes are the identifier everywhere

**Decision:** Delete `Spree::Country` and `Spree::State` as ActiveRecord models
in 6.0 — tables, seeds, factories, and every `country_id`/`state_id` FK. The
constants survive as gem-backed value objects (`ActiveModel::Model`, data from
the `countries` gem; `carmen` removed). Consumers store `country_iso` (+
`state_abbr` always paired with its `country_iso` — subdivision codes are not
globally unique). Address validation semantics are preserved exactly
(`STATES_REQUIRED` countries validate `state_abbr` against gem subdivisions
with name→abbr promotion; elsewhere `state_name` stays free text). Full design:
`6.0-drop-country-state-models.md`.

**Why:** No competitor points an address at a state row (Vendure has a Province
entity and still stores a string on Address); Medusa and Vendure's country
tables are materialized caches of static ISO lists. Our public surface is
already ISO-native — neither model exposes an `id` in v3, addresses serialize
flat ISO strings, the dashboard submits ISO only — so the AR layer was pure
internal overhead: two seed services, two gems (carmen + countries), duplicate
ISO→record resolution paths with divergent failure modes, and localized names
already delegating to `ISO3166::Country` with the DB column as fallback.

**Supersedes:** the FK member design in `6.0-delivery-zones.md`
(`DeliveryZoneMember` converts to `country_iso`/`state_abbr` strings; state
members gain their own `country_iso`) and — decisive on timing — the unshipped
`6.0-tax-provider.md` Phase 5, amended so `spree_tax_rates` columns are **born
as `country_iso`/`state_abbr` strings**, never FKs (verified 2026-08-07 the FK
columns don't exist yet; amending now avoids migrating the same columns twice).
The two admin endpoints still permitting raw `country_id`/`state_id` params
(customer addresses, order addresses) drop them. Sequencing: the table drop
lands after delivery-zones Phase D so the polymorphic `ZoneMember` is removed,
never string-converted.

**Constraint now:** no new `country_id`/`state_id` columns or
`belongs_to :country/:state` anywhere — new features store ISO strings
(`Promotion::Rules::Country` is the template).

## 2026-08-07: `Claim#claim_type` dropped — the reason vocabulary is the only "what went wrong" axis

Reverses the two-axis design in `6.0-returns-exchanges-claims.md`, which
paired a fixed `claim_type` (damaged / missing / wrong_item / other) with
the merchant-owned `Spree::ClaimReason`. The column, its
`class_attribute` list, the validation, the API field and the dashboard
"Problem" picker are all removed; `reason` stays, still optional.

**Why.** The two fields asked the merchant the same question twice. The
seeded claim reasons made it plain — "Arrived damaged" next to type
`damaged`, "Wrong item sent" next to `wrong_item`. Worse, `claim_type`
was required and unmodifiable while earning nothing: no code ever
branched on it (the model comment conceded "pure labels with no per-type
behaviour"), unlike `resolution`, which is closed precisely because each
value drives `Claims::Resolve`. Return and Exchange already carry a
reason and no type column, so dropping it makes all three consistent.

The coarse-fixed-axis-for-reporting argument is real but unearned here:
nothing reported on it. A future reporting need is better served by
grouping reasons than by a second required field.

**Migration.** `spree_claims.claim_type` is dropped in
`20260807120001_remove_claim_type_from_spree_claims.rb`. The 6.0 tables
are unreleased, but the creating migration already shipped to `6-0-dev`
and `main`, so this is a follow-up drop rather than an edit in place.
The Store API claims endpoint gains `reason_id`, which it never accepted.

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


## 2026-08-07: Provider gems live under spree/providers/

Established with the easypost move (`spree/easypost` →
`spree/providers/easypost`) while exactly one provider gem existed and
none had published. Rationale: the provider roster (easypost, stripe,
adyen, avalara, inpost, possibly meilisearch) will outnumber the four
platform gems (core/api/emails/dashboard), and a flat `spree/` stops
communicating what is load-bearing versus optional — Medusa's monorepo
draws the same line. Kept under `spree/` (not top-level) so the
`spree/**` CI path filters, gem-cache keys and starter globs keep
working. Gem names stay flat (`spree_easypost`, never
`spree_provider_easypost`) — the directory groups, the gem name is the
public identity. Mechanical consequences: CI matrix entries carry a
`dir:` field when it differs from the project name, and Bundler path
blocks need `glob: '{,*,*/*,*/*/*}.gemspec'` to reach the third level
(applied in the worktree server Gemfile; spree-starter needs the same
line when providers ship). `6.0-payment-gateways-monorepo.md` retargeted
to `spree/providers/stripe` / `spree/providers/adyen`.

## 2026-08-06: Integrations become the admin-managed credential surface; verify-before-activate

`Spree::Integration` (shipped 5.x, previously zero subclasses, no API,
no UI) becomes the single credential home for every provider seam —
delivery rates, tax, fulfillment, pickup point networks. New plan:
`6.0-integrations-admin.md`. Explicit `Spree.integrations` registry
(house pattern, no descendants-scanning); Admin API v3 CRUD + types
discovery reusing the `PreferenceSchema`/`Masking` machinery from
payment methods (secrets are `:password`-typed preferences, masked on
read, round-trip-guarded on write); dashboard `/settings/integrations`
gallery grouped by `integration_group` — the one page showing what is
connected to the current store. Semantics settled interactively:
**verify before activate** (saving credentials never makes a network
call; flipping `active: true` runs `can_connect?` and 422s on failure;
`POST /:id/test` for diagnostics) and **ephemeral connection status**
(no `last_checked_at`/`last_error` columns). Constraints now: new
provider gems ship an Integration subclass — no env-var credential
contracts for per-store providers; no per-provider credential UIs —
provider pickers deep-link to the integrations page.

## 2026-08-06: Pickup point provider contract hardened; no reference network gem in 6.0

Decided before any concrete `PickupPointProvider` exists, precisely
because none does: (1) providers are constructed with
`new(delivery_method)` — the current zero-arg construction leaves no
path to `store.integrations` for credentials; (2) `find_nearby` accepts
`zipcode:`/`query:` alongside `latitude:`/`longitude:` (postcode/city
search is the standard EU checkout pattern; map-widget storefronts skip
`find_nearby` and only use server-side `find_by_external_id`
validation). Both are free now and breaking later. **No reference
network provider (InPost/Sendcloud) ships in 6.0** — community/later,
with a how-to guide. The checkout flow itself is confirmed as
shipped: point selected during checkout at the delivery step
(`pickup_point_external_id` on rate selection, server-validated, frozen
into `fulfillment.pickup_point_data`).

**Amended 2026-08-06 (same day, Damian):** all pickup work beyond
already-shipped code — including the contract hardening above — is
**deferred to 6.1**; 6.0 is packed. The pickup point provider
interface is **not documented in 6.0 at all** — the v6 developer docs
cover only the delivery rate provider interface; a class-level comment
on `PickupPointProvider::Base` notes the constructor and `find_nearby`
signature change in 6.1, so the change breaks no sanctioned contract.
Accepted trade-off, recorded in `6.0-fulfillment-and-delivery.md`
(Implementation status + Phase 6). Constraint: no 6.0 doc or guide may
cover the pickup point provider interface.

**Second amendment 2026-08-06 (Damian):** `pickup_point` is also
removed from the `Spree.fulfillment_types` registry and the dashboard
`FULFILLMENT_TYPES` const — not selectable anywhere in 6.0; existing
rows stay loadable (inclusion validates on change only) and the shipped
endpoints still serve them; one-word re-registration in 6.1 restores
the surface. `local_delivery` is removed the same way, but as a **cut,
not a deferral**: it fails the plan's own modality-vs-segment test —
identical address/zone/provider/lifecycle semantics to `shipping`; the
local-delivery use case is a `shipping` method with a postal-code
DeliveryZone. It returns only alongside real provider behavior
(delivery windows, courier assignment). 6.0 built-in types:
`shipping`, `pickup`, `digital`.

## 2026-08-06: EasyPost is the reference delivery rate provider (Shippo pick reversed same day)

Resolves the EasyPost-or-Shippo pick left open on 2026-07-29/30. The
monorepo's reference `DeliveryRateProvider` (`6.0-delivery-rate-provider.md`
Phase 5) is built on **Shippo**. Competitor survey: no platform ships
direct per-carrier integrations in core — Shopify and WooCommerce built
their in-house label services on an aggregator (both historically
EasyPost-backed), BigCommerce leans on ShipperHQ, and the OSS field
(Medusa, Saleor, Vendure) ships a provider interface with aggregator
plugins, Medusa's ecosystem having standardized on Shippo. A direct
UPS/USPS/FedEx trio was rejected: three churning carrier APIs to
maintain, US-only coverage against Spree's heavily European base, and
worse merchant onboarding than one aggregator account. Between the two
aggregators, Shippo fits the reference provider's audience (default OSS
install, SMB merchant): simpler API surface, pay-as-you-go pricing with
no monthly fee, solid EU carrier set. The `spree_easypost` lineage
carries no weight — it targets the pre-6.0 architecture and would be a
rewrite regardless. The interface stays aggregator-agnostic; EasyPost,
Sendcloud (EU-first, strong service-point coverage) or direct-carrier
providers remain buildable as third-party gems on the same base class.

**Reversed 2026-08-06 (same day, Damian): EasyPost.** Two factors the
Shippo lean under-weighted: (1) **Spree's merchant profile skews
larger** — merchants with negotiated UPS/FedEx contracts who want to
connect their own carrier accounts, which is EasyPost's core BYOCA
(bring-your-own-carrier-account) model, not Shippo's SMB
default-account posture; (2) **Ruby SDK reality**: EasyPost maintains
its official `easypost` gem (7.6.0, Feb 2026), while Shippo's official
Ruby client last released in April 2020 and signals deprecation — for
a Ruby-first reference implementation that difference is decisive (the
Shippo path would mean hand-rolling and maintaining an HTTP client in
the provider gem). Everything else in the original entry stands:
aggregator over direct-carrier trio, aggregator-agnostic interface,
third-party gems welcome on the same base class.

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

## 2026-08-05: Tax provider contract carries treatments, identities and dates — refined after the #14056 community review

The provider contract in `6.0-tax-provider.md` was reworked after two
outside implementers (an EU VAT decision engine, a US rates API) reviewed
the RFC on spree/spree#14056. Every concern was verified before adoption:
against primary legal sources (the European e-invoicing standard, the VAT
Directive, the EU verification service's own documentation — citations now
live in the plan's **Regulatory background** section), the major provider
APIs (Avalara, Stripe Tax, TaxJar, Vertex) and platform practice (Medusa,
Saleor, commercetools, Shopify, Magento, Odoo). Decisions:

**TaxLine carries a taxability reason, not just an amount.** A zero from
reverse charge, an export and an exemption are different facts landing in
different boxes of a tax return, and European e-invoices must state the
category for every line. New `taxability_reason` column with an additive
vocabulary (Stripe's enum pruned, plus `intra_community_supply` and
`export` — Stripe's own values cannot tell cross-border goods from
services, or an export from a domestic zero rate), plus a jurisdiction
snapshot (`country_iso`/`state_code` — one-stop-shop returns are filed per
destination country). The invoice category and exemption reason codes are
deliberately NOT stored — they derive at invoicing time from the reason
plus order facts (the Odoo pattern; no surveyed platform stores them).
Core ships the reason→code lookup maps as code. Write contract: a row for
every item the provider formed a treatment for, including zero amounts.

**Buyer tax identity is a separate model, `Spree::TaxIdentifier`.**
Stripe's shape (typed kinds, multiple per customer, verification state)
with Magento's evidence discipline (VIES consultation number, validated
country/value — VIES has no historical lookup, so entry-time evidence is
the only proof that will ever exist). Dual-FK owner: customer (durable —
sole proprietors will never have a Company), cart (override), order
(completion snapshot, frozen via `readonly?`, `source`-stamped, no
correction path); company/company_location FKs arrive with the B2B plan.
Zero footprint on consumer orders. Live-read designs were rejected on
documented drift pain (Shopify B2B, Odoo).

**Validating a tax ID belongs to the identifier, not to a tax provider.**
The registry that can answer is determined by the number's *kind* (EU VAT
→ the EU service, UK → HMRC, and so on), never by a market — a customer
saves a tax ID on a profile before any order exists, so a provider-hung
`validate_tax_id` would force an arbitrary choice (a US sales-tax engine
asked to check an EU number, or an EU market on Internal declining while
a connected Avalara sits unused). The seam is therefore
`Spree.tax_identifier_validators`, a registry keyed by kind and empty by default —
core ships no registry client for any jurisdiction — so two extensions
covering different kinds coexist where a single swappable service would
let the second loaded silently disable the first. Validation splits the way Stripe's does: **format
synchronously, the registry asynchronously, and the tax treatment depends
on neither.** Format is a hard validation on save — whitespace/case
normalization, presence, then the registered validator's class-level
`valid_format?` (the `SearchProvider::Base.indexing_required?` shape) — so a
typo is a field error and never persists. Core asserts no format rules of its
own: a charset or length range spanning every tax regime would be an untestable
guess whose failure mode is rejecting a real business customer. The registry check runs after
commit on the address-geocoding precedent (`after_commit` enqueues, the job
does the I/O, `update_columns` writes back, a non-answering registry is
reported and recorded as `unavailable`), never during estimate, which reads
the stored result. Reverse charge follows the number's format, not its
verdict — Stripe applies it "regardless of its validity" — so a sale may
complete with `pending` and still be treated correctly; the verdict is
evidence, not arithmetic. **Magento's model was rejected:** synchronous
registry validation gating the treatment through customer groups, whose own
ecosystem documents the cost (a third-party module exists solely to add
caching and offline fallback for the unstable registry, and per-transaction
validation cannot run at all under external checkouts). A tax provider gem
may register itself as the validator for kinds its service can check.

**Exemption is a typed estimate input plus the TaxLine outcome — the
boolean `exempt?(order)` is removed** (wrong arity: per jurisdiction, per
item, and the reason is the audit artifact; no provider API exposes an
exempt? query). `Spree::TaxExemption` value objects (mirroring the future
certificate row, with typed per-item overrides) are assembled by the
`tax_resolve_exemptions_service` dependency (default `[]`) — a seam because
the real implementation, certificate filtering by active status and
jurisdiction, is the B2B integration point. The identifier chain gets no
seam: it is a fallback `||` and lives as `#resolved_tax_identifier` on the
`Spree::Purchase::Taxation` concern beside `tax_address`. No exemption flags
on customer, order or line items. The `set_tax_line_context` hook is NOT
the channel for typed inputs — it narrows to untyped provider extras
before the 6.0 hook freeze. `TaxExemptionCertificate` stays in the tax plan
as its last phase, gated on Company existing, and gains `reason_code` — the
field providers actually consume as an entity use code, missing from the
original sketch.

**Dates are explicit.** `estimate`/`refund` take the rates-effective tax
date (unanimous provider practice, and legally the rate in force when the
sale happened is the one that applies), kept distinct from the
document/posting date. Refund becomes
`refund(order, return_items, tax_date:)` — supports both recompute-at-
original-date (Avalara/Vertex) and derive-from-recorded (Stripe/TaxJar);
the Internal provider only ever derives (TaxRate rows are unversioned).
The "credit note corrects the original filing period" claim from the
thread was checked and not adopted: a return is reported in the period its
credit note is issued, and only correcting a genuine error reopens the
original period.

**Capability honesty.** Providers declare unsupported domains; Internal
declares no destination-based US local tax (state-level rates cannot
express county/city/district stacking — silently under-collecting lands
on the merchant), no OSS threshold tracking, no reverse charge (unvalidated
ID → normal VAT, the protected default), no ID validation. `estimate`
A runtime indeterminacy channel on `estimate` was
considered and deferred: both cases the review raised (one-stop-shop
thresholds, Internal against US local rates) are answered by the capability
declarations at configuration time, nothing in core would consume a
per-calculation verdict, and unlike a hook key a return value can be added
later without breaking providers. `estimate` keeps its current signature —
the rows it writes are its output. Per-Market provider selection is
reworded to selection-not-construction: the market names the provider,
providers stay stateless and argless (the shipped `Base` shape), the
shipped global config class stays as the fallback.

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

1. **`6.0-payment-method-rules.md`** — `Spree::PaymentMethodRule` STI
   (Channel / Market / OrderTotal / CustomerGroup rules), mirroring the
   PromotionRule/PriceRule/OrderRoutingRule house pattern; enforced through
   the single `Order#collect_frontend_payment_methods` seam; storefront-only
   (admin/backoffice bypasses). Supersedes the "payment methods have no
   distribution concept" rationale in
   `5.6-6.0-single-store-promotions-payment-methods.md` — the single-store FK
   stands, eligibility is layered on via rules.
2. **`6.0-channel-markets.md`** — optional Channel→Markets allowlist
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

> **Superseded in part by 2026-08-17.** The *split* stands — the marketplace
> seller and the procurement source are separate models — but the marketplace
> model is now `Spree::Seller` (`sel_`, `spree_sellers`), not `Spree::Vendor`.
> `Spree::Supplier` is unchanged.

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
**Owned by `6.0-typed-stock-movements.md` as of 2026-08-13** — it ships as that
plan's Phase 0, ahead of the new movement columns, so they are born beside a
final name. Bridges: constant, association and column aliases plus dual-emitted
`stock_item.*` events for one release; the prefix change and the endpoint rename
take the break.

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

> **Amended 2026-08-09 on one point:** `public_metadata` is **merged into
> `metadata`, not discarded**. "Unused" holds for Spree's own code but is not
> provably true of host applications, and a dropped column has no rollback. The
> merge runs inside the migration. Everything else below stands — see the
> 2026-08-09 entry at the top of this file.

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
direction separately via `6.0-channel-markets.md`. If more convenience is
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
`6.0-payment-method-rules.md` (ItemTotal + Weight first; Channel/Market/
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
  `6.0-payment-method-rules.md` lands. Credentials stay on the method
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
`6.0-payment-method-rules.md` specced a fifth. The empty-list fallback
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
`6.0-payment-method-rules.md` updated to the new form.

Known debt: the registry is a lodger inside `PreferenceSchema` (which
`Spree::Base` includes, so ~200 models carry class methods only six use),
and `Spree::CalculatedAdjustments` resolves an equivalent registry
separately. Extract a `Spree::RegisteredSubclasses` concern when a family
needs the registry without preferences — that second consumer is the
trigger, and it would absorb CalculatedAdjustments too.
## 2026-08-06 — Converted-away columns outlive the release that converts them

`spree_tax_rates.zone_id` stays in the schema through 6.0 even though
nothing reads it, and is dropped in 6.1. The reason is ordering, and it
generalizes: a data task named in the upgrade manifest runs *after*
`db:migrate`, so a migration that removes the task's input column in the
same release destroys the data the task exists to convert — and leaves a
merchant no source to re-run from if the conversion needs repeating.
Tax rates therefore gain a jurisdiction of their own (`country_id`/`state_id`
here; changed to `country_iso`/`state_code` on 2026-08-12, see above), every `zone_id` reader
is severed (the association, the zone scopes, and `Zone#has_many
:tax_rates`, whose `dependent: :destroy` would otherwise delete live
rates when a shipping zone is destroyed), and the column is left in
place, unread. `spree_adjustments` already worked this way under
`migrate_adjustments_to_typed_rows`, which keeps the legacy table as its
rollback source; treat that as the pattern rather than the exception.

## 2026-08-07 — StateChange and LogEntry removed; lifecycle events are the only audit

**Decision:** Delete `Spree::StateChange` and `Spree::LogEntry` in 6.0 — models,
associations, state-machine writers, `Payment::Processing#record_response`,
`Refund#create_log_entry` and the `Order#log_state_changes` shell. This
supersedes the cart/order-split note that payment/fulfillment machines keep
their `StateChange` rows.

**Why:** Both were write-only. Nothing in the 6.0 codebase — no serializer, no
API endpoint, no dashboard page, no event payload — ever read them back; the
legacy Rails admin screens that displayed them are gone. Lifecycle events
(`payment.completed`/`voided`, `fulfillment.ready`/`fulfilled`/`canceled`/
`resumed`, `order.*`) are the sanctioned audit, the same call already made for
Order rows. Removing LogEntry also retires YAML-serialized gateway responses
in the database (a historic deserialization CVE surface); gateway dashboards
and `PaymentSession` own transaction forensics now.

**Tables survive to 6.1:** `spree_state_changes` and `spree_log_entries` stay
(same pattern as the returns-chain tables). The 5.6→6.0 upgrade tasks that
touch legacy rows (`migrate_incomplete_orders_to_carts`,
`migrate_shipping_to_delivery`) read the table through anonymous ActiveRecord
classes. Both tables drop in 6.1 alongside `spree_adjustments`.

**Kept:** `Spree::PaymentCaptureEvent` — functional money data, not audit:
`Payment#captured_amount` sums it, partial capture and capture-on-dispatch
depend on it, and the Admin API exposes `captured_amount`.

## 2026-08-07 — Admin RBAC: one grant system, staff-only, catalog = scope vocabulary

**Decision:** (from spree/spree#14164; plan `6.0-admin-rbac.md`) Role
permissions become database-backed as flat `read_<resource>` /
`write_<resource>` keys — the same vocabulary secret API keys use. One
declarative catalog (resource → CanCanCan subjects → UI group) is the single
source of truth: `Spree::ApiKey::SCOPES` derives from it, and the dashboard
role editor and API-key scope picker share one `PermissionPicker` fed by
`GET /api/v3/admin/permissions`. **Permission sets are deleted at 6.0 with NO
compatibility bridge** — a deliberate exception to the one-release-bridge
convention: this is a system removal, not a rename, and a shim would carry the
runtime-union machinery the removal exists to kill. Old initializers fail
loudly at boot (`NameError` on the deleted constants; `assign` raises with an
upgrade-guide pointer). **Roles are pure data:** no `Spree.permissions.grant`,
no runtime merge, no union — the editor is WYSIWYG; "roles as code" is seeds
(plain ActiveRecord) or the Admin API; extensions register catalog resources,
never roles (matching Saleor/Vendure/Shopify — roles are rows everywhere). A
`mutable` column (NamedType pattern) covers locked roles: admin seeds
`mutable: false`; hosts can lock compliance roles the same way. Record-level
custom rules migrate to a `Spree::Dependencies.ability_class` swap — the one
low-level escape hatch (`register_ability` was dropped with the sets, 6.0
having no undocumented registration API to inherit).
Upgrade is fail-closed: pre-existing custom role rows come up with empty
permissions until filled in the editor. Enforcement unifies on
the key gate: `ScopedAuthorization` generalizes so every admin request — JWT
staff or secret key — checks its principal key set against
`<read|write>_<scoped_resource>`; CanCanCan is demoted to internal plumbing
behind it (still compiled from keys; nothing public configures it; dropping it
from the admin path is a 6.1 option, not a goal). A new `staff` pair splits
out of `settings`; admin-role protection moves onto the `Spree::Role` model
(NamedType precedent — sk principals never consult CanCanCan). Resource
granularity reaffirmed; full-page editor; client-side templates, no seeds.

**The system is staff-only.** The storefront has no roles: `:default` /
`DefaultCustomer` cease to be public concepts and the customer baseline
(ownership conditions, guest tokens) becomes internal ability code, with
scope-fetching the primary enforcement. Role resolution runs only for
admin-user principals (aligns with the platform-auth Customer/Staff split, and
drops a per-request `role_users` query for customers). B2B company-account
roles (buyer/approver, hierarchies, spend limits — Enterprise) are explicitly
a separate future system: the vocabulary must not be shared (`write_orders`
means "manage the store's orders" to staff and "place my company's orders" to
a purchaser), matching commercetools/Shopify B2B/Medusa, which all keep
account roles apart from staff RBAC. Catalog/product visibility per customer
group or company is data scoping, never a permission key.

**Why:** the hard parts already shipped — the scope vocabulary and
per-controller `scoped_resource` declarations (5.5), the `RoleGrantGuard`
escalation check, store-scoped `RoleUser` assignments resolved per store by
`Spree::Ability`, and the `/me` rules dump the SPA mirrors. Unifying on them
turns "build an RBAC system" into "expose the one that exists". Two softer
designs were drafted and rejected the same day: sets kept as bundles over the
catalog, then a one-release `assign` bridge with an import task — each
preserved grant-source duality (union semantics, locked "granted in code"
rows, mixed escalation math) purely for back-compat comfort, in the release
whose point is the breaking window, for a migration that is genuinely a
five-minute UI task.

**Reviewer constraints:** no new `PermissionSets::` classes or `assign` calls
anywhere; every model a new admin controller authorizes must be covered by a
catalog entry, or custom roles cannot reach the endpoint; new sensitive
resources get their own catalog resource instead of riding `settings`;
storefront code must never consult `Spree::Role` or the catalog.

## 2026-08-08 — Store API drops CanCanCan; storefront access is a swappable policy

**Decision:** The Store API (v3) no longer consults CanCanCan anywhere.
`Spree::Ability` is staff-only — a customer principal's ability has no rules —
and the generic `authorize_resource!`/`authorize_parent!` hooks plus the
`accessible_by` collection filter moved from the shared v3 `ResourceController`
down to the Admin branch. Storefront authorization is ownership: account
controllers read through `current_user` (scope-fetching, unchanged), catalog
endpoints have no per-record check (the old `accessible_by` calls sat on
unconditional `can :read` grants — no-op filters), and the two checks a scope
cannot express — cart/order access proven by JWT ownership OR a guest token,
plus the guest-token order-listing scope — live in
`Spree::Storefront::AccessPolicy`, swappable via
`Spree::Dependencies.storefront_access_policy_class`. Denials raise
`Spree::Storefront::AccessDenied`, rendered identically to CanCan's 403.

**Why:** Two reasons converged. First, the storefront never needed a rule
engine — its "rules" were ownership conditions and token blocks, and CanCanCan
block rules can't power `accessible_by`, so controllers carried both a scope
AND an `authorize!` for the same fact. Second, the Enterprise B2B module
(`6.1-channels-catalogs-b2b.md`) must extend storefront authority without
decorating controllers, and a policy object is the right seam: **access
widening** (approver sees company-location purchases) = subclass the policy and
override `scope`/`readable?`/`writable?`; **action vetoes** (approvals,
spending limits) = checkout workflow `validate` hooks; **catalog visibility**
(per-location catalogs) = the products-for-context data scoping. Enterprise
implements, open source owns the seams. Competitors ship no storefront rule
engine (Medusa/Saleor/Vendure); Shopify B2B contact permissions are fixed
server-side roles.

**Consequences:** Extensions must not add storefront `can` rules or call
`authorize!` in Store API controllers — widen the access policy or hook a
workflow instead. The admin side is untouched: staff JWT + CanCanCan, secret
keys + scopes. `register_ability`/`remove_ability` are gone with the sets
(`Spree::Dependencies.ability_class` is the admin-side escape hatch).

**Alternative considered and rejected (2026-08-08):** a dedicated storefront
ability class fed by permission sets — two abilities, staff (catalog keys) and
storefront (sets/code). Rejected on three grounds: a storefront rule engine
only means something if store controllers consult it, which restores the
scope-plus-`authorize!` dual bookkeeping across the store surface; OSS
customers are all identical, so a storefront set registry would hold exactly
one configuration (the old `DefaultCustomer`) — code plus registry
indirection; and the B2B requirement itself decides it — a company admin
managing roles/employees in a UI needs **data** roles (Enterprise
`CompanyRole` with capability keys, the commercetools associate-roles shape),
which code-defined sets cannot provide. The policy protocol is generic
(`readable?`/`writable?`/`scope` with an ownership default), so wishlists,
newsletter subscriptions and any new resource route through the same seam
with no wiring; `/customers/me/*` endpoints stay owner-scoped by definition.
Full B2B architecture: `6.1-channels-catalogs-b2b.md` → "Company roles and
approvals".

## 2026-08-12 — OpenTelemetry: notifications in core, spans in an optional gem, traces only

**Decision:** Spree ships first-class OpenTelemetry support
(`docs/plans/6.0-opentelemetry.md`) as two layers. Core's instrumentation
contract is `ActiveSupport::Notifications` — core takes **no** OpenTelemetry
dependency, and the notification catalog (workflow `perform`/`step`/`hooks`,
events dispatch, webhook delivery, payment gateway boundary) becomes public
API with the same additive-only rule as workflow hook keys. A new optional
top-level engine `spree/opentelemetry` (gem `spree_opentelemetry`, beside
core/api/emails — NOT under `spree/providers/`, which means commerce
providers with an `Integration` credential surface) boots the OpenTelemetry
SDK purely from standard `OTEL_*` env vars (Saleor-style; no host
initializer; `OTEL_SDK_DISABLED` honored), installs the Rails
auto-instrumentation umbrella, and translates Spree notifications into spans
via hand-rolled subscribers following the `Spree::EventLogSubscriber`
reload-safety pattern. 6.0 ships the trace signal only — the Ruby metrics and
logs SDKs are experimental, so RED metrics are collector-derived
(spanmetrics) and log correlation is trace IDs in log tags, never the logs
SDK.

**Consequences for other work:**
- An outbound network call inside a workflow is always an `external_step`,
  never a plain `step` — `external_step` now also marks the span as CLIENT
  (`external: true` in the `step.spree_workflow` payload), so the
  distinction is a tracing contract on top of the transaction guard.
- Never `rescue StandardError` around workflow execution in instrumentation
  or middleware: `FailureSignal`/`Halted` inherit `Exception` and would be
  silently missed.
- Anything added to an instrumented notification payload must be PII-safe
  (prefixed IDs, names, counts — never payloads, emails, addresses,
  credentials); assume every payload key ends up on someone's dashboard.
- Telemetry configuration is process-level deployment config (env vars) —
  never a `Spree::Config` preference, store preference, or admin UI surface.

## 2026-08-12 — spree-starter bundles spree_opentelemetry by default; Sentry keeps errors

**Decision:** spree-starter adds `spree_opentelemetry` to its Gemfile
installed, not commented out (amends the plan's original "commented in the
Gemfile"). The official Docker image is built from the starter, so image
users cannot edit the Gemfile — and since the gem is dormant until a standard
`OTEL_*` exporter variable is set, bundling it makes tracing a pure
environment-variable opt-in for container deployments. Sentry (already in the
starter) and OpenTelemetry divide cleanly: Sentry keeps error capture, the
OpenTelemetry stack owns tracing. The starter must NOT set Sentry's
`traces_sample_rate` — that would double-instrument every request into two
disconnected trace systems. Teams that want traces in Sentry use the
`sentry-opentelemetry` OTLP integration, and **ordering is load-bearing**
(2026-08-12 code review): Sentry registers its span processor synchronously
inside `Sentry.init` (`after(:configured)`), which requires the OpenTelemetry
SDK to already be installed — so the recipe is `SpreeOpenTelemetry.configure
{ |c| c.enabled = true }` + `SpreeOpenTelemetry.install!` at the top of the
Sentry initializer, before `Sentry.init` with `config.otlp.enabled = true`,
plus `OTEL_TRACES_EXPORTER=none` so the SDK wires no competing default
exporter (Sentry derives its endpoint from the DSN). Auto-detecting Sentry's
OTLP mode from `spree_opentelemetry` was tried and reverted — the gem
installs after `load_config_initializers` by design, so detection can never
run early enough. A bare SENTRY_DSN deliberately does NOT activate tracing:
Sentry bills for ingested spans, so error capture must never silently become
span ingestion. The starter's own sentry initializer encapsulates the whole
recipe behind an env var (e.g. `SENTRY_OTLP_ENABLED=true`) so container
users still flip it without code. Docs:
`docs/developer/deployment/telemetry.mdx`.

## 2026-08-14 — Duties are fees, not tax lines; landed cost is a provider gem, not core

**Decision:** Customs duties are modeled as `Spree::Fee` rows with `kind:
'duty'` — never `TaxLine` rows and never a new table. Duty rows snapshot their
calculation inputs (`hs_code`, `country_of_origin`, `rate`, provider,
guaranteed flag) in `metadata`, so re-classifying the catalog never rewrites
order history. Classification lives as three plain nullable columns on
`spree_variants` (`hs_code`, `country_of_origin`, `customs_description`),
shipped together with their first consumer: the EasyPost provider's customs
declaration, built for international rate quotes as well as label purchases
(today it sends `customs_info: null`) — the two share one shipment builder, so
a label always carries the declaration and duty terms its quote was priced
with. Fees become shopper-visible — the Store API cart/order serializers
gain `fees` + `fee_total`. Duty estimation enters the cart exclusively through
`Spree.adjusters` (a provider gem's adjuster writes the duty fee rows during
recalculation); core ships no calculation engine and no landed-cost guarantee
— a guarantee requires being importer of record, which is a service business,
not a code path. Duties are excluded from the default taxable-item set in the
shared `Spree::Purchase::Taxation#taxable_items` (Cart and Order), so **every**
provider inherits the exclusion rather than each reimplementing it; a provider
that does tax duties passes its own item list. Import VAT on a duty therefore
exists only as provider-written `TaxLine(fee_id: …)` rows, preventing domestic
tax stacking and double-counting. Plumbing ships in 6.0; the landed-cost provider gem and a
`Spree::Market` shipping-terms setting are 6.1.

**Consequences:** No duty math against the live catalog on existing orders —
the `metadata` snapshot is the source of truth. New fee-producing code writes
typed `Fee` rows via adjusters or the order-locked fee services. Store
serializer work must not assume fees stay hidden. A dedicated duty-provider
contract (estimate/commit/void) is deliberately NOT built — it graduates only
if the first provider gem proves the need. Plan:
`6.0-duties-and-custom-fees.md`.

## 2026-08-15 — Vendor users are `Spree::AdminUser`; vendors get their own API branch, JWT audience and login surface

**Context:** The marketplace plan (2026-07-14 wording) said vendor users would
"hit the same admin API with JWT + vendor-scoped abilities — no separate
vendor routes", with abilities built from `PermissionSets::VendorUser`
carrying `vendor_id: user.vendor_ids` hash conditions. Two shipped PRs changed
the ground under that: platform-owned auth (#14380) made the platform
two-principal (`Customer` buys, `AdminUser` operates a back office, one auth
stack on that class), and first-class RBAC (#14412) removed permission sets
with no bridge — the catalog is flat `read_*`/`write_*` keys with **no
conditions**, tenancy is controller scoping, and `Spree::Ability#staff_roles`
already excludes vendor-resourced `RoleUser` rows as belonging to "their own
panel's ability" (the RBAC plan's 2026-08-08 direction: vendor-panel endpoints
scope-fetch through `current_vendor`). Two questions were re-examined: should
vendor staff be a separate model, and should they reuse the Admin API with
narrower permissions.

**Decision:** *Reuse the principal, separate the surface.*

- **Vendor staff are `Spree.admin_user_class`. No `VendorUser` model, no
  `Spree.vendor_user_class`.** A third principal would duplicate
  `has_secure_password`, lockout, password policy, password-reset tokens,
  `UserIdentity` SSO linking, invitation acceptance and the refresh-cookie
  flow — every future MFA/passkey improvement, twice. Membership is by
  `RoleUser.resource_type` (`Spree::Vendor` vs `Spree::Store`), never by
  `store_id`; one account may hold a store role and a vendor role at once.
- **A dedicated `/api/v3/vendor` branch** (third v3 branch beside `store` and
  `admin`, `Vendor::BaseController`/`ResourceController` anchors). Every
  endpoint scope-fetches through `current_vendor` (`X-Spree-Vendor-Id` +
  membership; the store is derived from the vendor, never from a header) —
  IDOR by construction, the same mechanism that isolates stores on the admin
  branch. Vendors never call the Admin API. What a vendor may not do is an
  endpoint that does not exist, not an ability rule. Own serializer branch off
  the store serializers, own OpenAPI spec; admin controllers are never
  subclassed into the vendor namespace (inherited `current_store.*` lookups
  are the leak).
- **Isolation at the token layer, not only at membership:** own
  `JWT_AUDIENCE_VENDOR = 'vendor_api'` (admin and vendor branches reject each
  other's tokens at decode, before any membership check); own
  `Spree.vendor_authentication_strategies` + `/vendor/auth/*` (login policy
  is per surface, so staff can be SSO-only while vendors use passwords — the
  vendor login refuses accounts with no vendor membership);
  `spree_refresh_tokens.audience` enforced on refresh with a separate cookie.

**Rejected:** a separate `VendorUser` model — buys only type-level separation
on top of the three token-layer measures, at the cost of a duplicated auth
stack and split identities. Reusing admin controllers with vendor
permissions — not expressible in the conditionless catalog; would require
per-principal forks in ~300 endpoints' `scope`/`find_resource`/incidental
lookups (`stock_location_id`, `reason_id`, `variant_id`), each miss a
cross-vendor read or write inside the same store.

**Consequences:** `AdminAuthentication#current_user_member_of_store?` must
match `resource_type: 'Spree::Store'` (today it matches `store_id`, which a
vendor-resourced assignment passes — scope-exempt admin endpoints such as
`/admin/tags` and `/admin/store` would be reachable by a vendor-only user
once vendors exist); ship this ahead of the Vendor model. `Role#audience` and
a vendor-grantable marker on `register_resource` come from the RBAC plan's
settled direction. Never add a login surface without its own strategy
registry and JWT audience; refresh tokens carry the audience they were minted
for. Accepted trade-off: password policy and lockout stay shared between
staff and vendors (model-level), and thin controllers are duplicated across
the two branches. Plan: `6.0-multi-vendor-marketplace.md` Decision 10;
supersedes the 2026-07-14 "collapse into ability scoping" wording there and
extends `6.0-admin-rbac.md`'s vendor-scoped-assignments direction.

## 2026-08-15 — Marketplace: facilitator-tax flag and payout floor are core; the policy around them is Enterprise

**Decision:** Three of the marketplace plan's long-open questions were settled
the same day as the vendor-principal decision. (1) Store-credit and gift-card
payments on a split checkout are group-level `Payment`s with their own
`PaymentSplit` rows, prorated by child totals like the gateway payment — one
attribution rule for every payment source. (2) `spree_vendors.minimum_payout_amount`
(nil ⇒ store preference) ships in core and the sweep carries sub-threshold
balances forward; a percentage holdback with a release window stays Enterprise.
(3) `spree_vendors.tax_remittance` (`vendor` | `platform`, default `vendor`)
ships in core and core's transfer basis honors it (`platform` ⇒
`total − tax_total − commission`); *deciding* that a vendor is
platform-remitted (US facilitator nexus, EU deemed-supplier rules) stays
Enterprise "automatic taxes", which sets the column. Vendor-scoped promotions
are deferred past 6.0 with their shape recorded.

**Why:** the ledger math must be provider- and edition-independent so
Enterprise never forks core ledger code — it configures rows, it does not
override the basis service. **Consequences:** amends the marketplace plan's
Decision 9 note that facilitator mode is "not core" (the flag and the math
are; the policy is not). Plan: `6.0-multi-vendor-marketplace.md`.

## 2026-08-17 — The marketplace seller is `Spree::Seller`; `Vendor` is retired

Reverses the naming half of 2026-07-14. That entry gave the marketplace the
`Vendor` name on two grounds, and by 2026-08-17 both were gone: the user docs'
Vendors area is being rewritten wholesale for the 6.0 stable release, and there
is no Enterprise production data to keep `ven_` continuity with. Nothing was
released, so nothing had to be carried over — the migrations were edited in
place rather than added to.

**The decisive argument is Amazon's, and it is about the second party.** Spree
models both a business selling *through* the marketplace and a supplier the
merchant buys stock *from*. Amazon names those two relationships in opposite
directions: Seller Central hosts third parties, Vendor Central buys from
suppliers. So `vendor` was the single worst available word for a marketplace
seller in a schema that also contains the supplier — every integrator with
Amazon experience reads `vendor_id` as the procurement relationship. Shopify
agrees by construction: when it built purchase orders it chose `supplier`.

`Seller` also matches the buyers we are selling to. Gartner's category is
"Enterprise Marketplaces" and its definition says "third-party sellers";
Forrester's Wave criteria are "seller onboarding" and "seller compliance".
Neither analyst firm uses "multi-vendor" for anything. VTEX (`sellerId`,
`/sellers/`), Marketplacer (`Seller`), Amazon (`sellerId`) and Mercur
(`seller`, `sel_`) all name the entity that way in public APIs. Mirakl is the
one mixed case — its data entity is `shop_id` while its docs and API routing
say seller — and its `shop` is a legacy artefact we have no reason to inherit.
Spryker's `merchant` is the sole enterprise divergence, and "merchant" fits
Spree badly since it most naturally means the store owner running the
marketplace.

**Scope:** `Spree::Seller`, `spree_sellers`, prefix `sel_`, `seller_id`,
`current_seller`, `SellerMailer`, `read_sellers`/`write_sellers`, and all three
API surfaces (store `/sellers` public profiles, admin `/sellers` operator CRUD,
and the seller-facing `/api/v3/seller` branch). `Spree::Supplier` is unchanged
and keeps the procurement source — 2026-07-14's *split* stands; only which word
lands on which side changed.

**Category naming, separately:** describe the product as a **marketplace**
platform, not a "multi-vendor" one. Every platform leading with "multi-vendor"
sits in the $29–$6,999 plugin tier (CS-Cart, Dokan, WCFM, Yo!Kart); every
analyst-recognised vendor says "marketplace platform". Keep "multi-vendor
marketplace" in SEO surfaces only — meta descriptions, comparison pages — which
is exactly what Marketplacer does, capturing the search volume without letting
the term define the positioning. Internal branch and plan filenames keep their
`multi-vendor` prefixes for stable cross-references; this is positioning, not
engineering.

**Consequences:** `Rails`/Bundler `vendor/` directories, gemspec
`{app,config,db,lib,vendor}` globs, the "vendor lock-in" idiom, and EasyPost's
carrier-meaning "vendor" are all deliberately untouched — a blanket rename
breaks CI and ships broken gems, and each of those was caught only by running
the suites. `docs/user/vendors/` and the rest of the published documentation
are **not** renamed here; they are part of the 6.0 stable docs overhaul. Plan:
`6.0-multi-vendor-marketplace.md`.

## 2026-08-18 — Store credits lose their category and type

`Spree::StoreCreditCategory` and `Spree::StoreCreditType` are retired.
Both were inherited reference tables that no longer answered a question
anything asked. A type was never created by any code path — no seed, no
writer — so the "priority" it was meant to give store-credit redemption
ordered on `NULL`, and which of a customer's credits got spent first was
whatever the database returned. A category carried a name and an
`expiring`/`non-expiring` label that nothing enforced: store credits have no
expiry (gift cards do, on their own row), gift-card redemptions never set a
category, and the only readers were a read-only admin endpoint feeding a
dropdown nobody could manage.

**What answers the question instead.** Why a credit exists is
`StoreCredit#originator` (the return, exchange, claim or gift card that
issued it) plus the free-text `memo` the refund workflows already write.
Which credit is spent first is `StoreCredit.oldest_first` — deterministic
and what shoppers expect. This is the shape every hosted platform ships:
a balance with a note, no taxonomy.

**Scope.** Refund workflows stop passing a category; the admin store-credit
endpoint drops `category_id`/`category_name` and the read-only
`/admin/store_credit_categories` routes are gone, as are the dashboard
picker, the admin SDK resource, the seed and the `settings` catalog entry.
`Spree::Config[:non_expiring_credit_types]` is deprecated as
"nothing reads this". `spree:upgrade:fold_store_credit_categories` copies a
legacy category name into the memo of credits that have none, so the only
information a category row held stays visible.

**Kept for one release.** Both classes survive as deprecated shells on their
existing tables (warning on instantiation; `default_refund_category` and
`order_by_priority` warn and delegate), and `spree_store_credits.category_id`
/ `type_id` stay as frozen columns — never written — so extensions
referencing the constants fail loudly and the fold step has its source. 6.1
drops the two tables, the two columns and the shells.


## 2026-08-19 — Avalara reference gem: `spree_avalara` in the monorepo, whole-owner fail-closed estimate

The 6.0 first-party tax provider (tax-provider plan, Phase 6) gets its own
plan — `6.0-avalara-provider-gem.md` — and lands as a **new monorepo gem at
`spree/providers/avalara`**, not a rewrite of `spree_avatax_official`
(which stays the 5.x line and becomes the salvage + upgrade source). The
gem is **`spree_avalara`** / `SpreeAvalara`, superseding the
`spree_tax_avalara` working name: a class named exactly `Integration`
derives its `api_type` from the outer module, so `SpreeAvalara::Integration`
speaks `'avalara'` on the wire — the same string as `TaxLine.provider_id`
and the locale key — and no Zeitwerk inflection is needed.

Design headlines, each recorded with rationale in the new plan: `estimate`
prices the **whole owner** per API call (Avalara is a whole-document
engine; the `items` subset is ignored, replace-all is honored by sweeping
and rewriting only `provider_id: 'avalara'` rows, and a 5-minute response
cache absorbs the single-item call sites) and **fails closed** — an
unreachable Avalara raises rather than under-collecting. `taxability_reason`
is mostly a deterministic fold of Avalara's structured reason fields
(`nonTaxableType`, `exemptCertId`/`exemptNo`, `rateTypeCode`,
`isItemTaxable` — verified against the legacy gem's recorded cassettes);
only the `intra_community_supply` vs `reverse_charge` split derives from
request-side facts, because Avalara reports the zero rate but not that
distinction. Commit is idempotent via
`create_or_adjust_transaction` with the document id in `order.metadata` —
no ledger table. The gem consumes core's exemption seam as-is (company
certificates through `tax_resolve_exemptions_service` — no swap, no
gem-owned storage; whether customer-level/no-Company exemptions deserve
first-class handling is the plan's open question, preferring a core
extension — customer-resolvable certificates — over gem storage, with the
legacy user columns preserved as the migration source), and
enforces Avalara address validation at `carts.complete.validate` (fail-open
on transport) — deliberately not `Spree.validators.addresses`, which fires
on every address-book and admin save with no checkout context.

Two knock-ons settled elsewhere: **`Market#tax_inclusive` stays** (the gem
wires it as the external-provider inclusive-price signal, answering the
tax-provider plan's Phase 9 "wire or drop") — but read
**destination-derived**: the flag comes from the market covering the tax
address's country, falling back to the owner's market, never naively from
`owner.market`. The browsing market can diverge from the tax destination
(currency changes re-resolve the market by currency past the one
address-clearing guard; bill-address tax destinations are never validated
against markets; a missing country hint drops a cart onto the default
market) — the recorded 5.x bug fixed by spree_avatax_official#198, whose
policy the gem restates. And the gem's upgrade task points **only blank**
`Market#tax_provider` values at Avalara — a value someone set, including
an explicit Internal, is never rewritten.
