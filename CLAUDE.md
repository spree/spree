# Spree Commerce — Development Rules

## Plans & Architecture Decisions

All feature plans live in `docs/plans/` using the template at `docs/plans/_template.md`. Never create plans elsewhere.

When proposing significant architectural changes:
1. Check existing plans in `docs/plans/` for conflicts
2. Create or update a plan using the template before implementing
3. Pay special attention to "Constraints on Current Work" sections — these apply even when you're not implementing that plan directly

Use `/project:create-plan` and `/project:update-plan` for plan management.

Active plans (6.0 target, work pending):
- `6.0-cart-order-split.md` — Cart/Order model separation, polymorphic LineItem
- `6.0-admin-api.md` — Admin REST API conventions, auth, endpoint list (~300 endpoints)
- `6.0-admin-spa.md` — React admin architecture, extension points, table registry, i18n + server-error mapping
- `6.0-product-types.md` — Prototype → ProductType rename, MetafieldDefinition schema enforcement
- `6.0-remove-master-variant.md` — Eliminate is_master, add default_variant_id FK on Product
- `6.0-split-adjustments.md` — Replace polymorphic Adjustment with TaxLine, Discount, Fee
- `6.0-typed-stock-movements.md` — Replace generic StockMovement with typed kinds + concrete FKs
- `6.0-normalize-state-to-status.md` — Rename state → status on Payment, Shipment, InventoryUnit, ReturnAuthorization, GiftCard
- `6.0-fulfillment-and-delivery.md` — Shipment→Fulfillment, ShippingMethod→DeliveryMethod, drop ShippingCategory, FulfillmentProvider strategy, pickup (merchant StockLocation) + pickup_point (third-party PickupPointProvider)
- `6.0-returns-exchanges-claims.md` — First-class Return, Exchange, Claim models replacing ReturnAuthorization/Reimbursement chain
- `6.0-platform-auth.md` — Drop Devise, own auth stack, User→Customer/Staff rename (RefreshToken shipped in 5.4)
- `6.0-tax-provider.md` — Per-Market TaxProvider, replaces TaxRate.adjust + Calculator, drop Zone model (TaxRate gets direct country/state FKs)
- `6.0-delivery-rate-provider.md` — Per-DeliveryMethod DeliveryRateProvider, replaces Estimator + Calculator, DeliveryZone with postal code support
- `6.0-rich-text-descriptions.md` — Drop ActionText storage, store HTML in text columns, sanitize on write, serve `description` + `description_html` in API (description_html serializer field shipped in 5.4)
- `6.0-inventory-operations.md` — StockTransfer lifecycle (draft → ready_to_ship → in_transit → received with partial receive), new `Spree::PurchaseOrder` + `Spree::Vendor` replacing today's "external receive" hack, variant + stock-location stock history panels. Consumes the typed-movement primitives from `6.0-typed-stock-movements.md`.
- `6.0-replace-taxons-with-categories.md` — Split Taxon into Category (hierarchy) + Collection (flat/rule-based). `Spree::Category < Spree::Taxon` alias + Category API surface shipped in 5.5; table rename + Collection pending.

Multi-version plans (some phases shipped, some pending):
- `5.4-store-api-naming-standardization.md` — Standardize API naming against industry (address fields, discounts, customer_note, label, brand/last4, etc.). 5.4 model/API aliases shipped; 6.0 column/table renames pending.
- `5.4-6.0-eu-legal-compliance.md` — GDPR (data export/anonymization, consent timestamps), Omnibus (PriceHistory, lowest-in-30-days), Consumer Rights (withdrawal period). 5.4 PriceHistory + `prior_price` shipped; GDPR endpoints + withdrawal period still pending.
- `5.4-6.0-custom-fields-rename.md` — Rename Metafields → Custom Fields. 5.4 API bridge + 5.5 `Spree::CustomField`/`CustomFieldDefinition` constant aliases shipped; 6.0 model/table rename pending.
- `5.4-6.0-product-media-system.md` — Product-level media gallery. 5.5 data model (spree_variant_media, media_type, focal_point, external_video_url) shipped; admin UIs in progress; 6.0 cleanup pending.
- `5.5-6.0-order-cancellation-and-approval.md` — First-class `OrderCancellation` + `OrderApproval` models. 5.5 models + migrations shipped; 6.0 drops denormalized columns.
- `5.5-6.0-display-on-to-boolean.md` — Collapse `display_on` tri-state to a single `storefront_visible` boolean. 5.5 bridge (`storefront_visible` accessor + Ransacker on `Spree::DisplayOn`) shipped; 6.0 schema rename pending.
- `6.0-order-routing.md` — Two-tier extension: pluggable `Spree::OrderRouting::Strategy::Base` + STI subclasses of `Spree::OrderRoutingRule`. Phase 1 (5.5) shipped: `Channel`, `OrderRoutingRule`, strategy base + Rules + Reducer + Legacy, `preferred_stock_location_id` + `channel_id` on Order. Phase 2+ (6.0) layers Catalog/Company on top via `6.0-channels-catalogs-b2b.md`.
- `6.0-channels-catalogs-b2b.md` — Channel + ProductPublication (replaces StoreProduct) + single-owner Product (`belongs_to :store`) + Publishing card (legacy admin + SPA) + `Channel#default` boolean shipped in 5.5. Channel-level gated storefront access (`storefront_access` enum + channel-owned `guest_checkout`, both with store fallback, enforced in the v3 Store API) targeted for 5.6. Catalog, Company/CompanyLocation/CompanyContact for B2B pending in 6.0. Multi-store catalogs (historic `Product has_many :stores`) move to the `spree_multi_store` extension.
- `5.6-6.0-single-store-promotions-payment-methods.md` — Migrate `Spree::Promotion` + `Spree::PaymentMethod` from multi-store (`has_many :stores` via `spree_promotions_stores` / `spree_payment_methods_stores` join tables) to single-owner `belongs_to :store`, mirroring the 5.5 single-owner Product migration. 5.6 (implemented): `store_id` FK + required-store presence via `Spree::SingleStoreResource`, backfill rake task (loud per-record deprecation on shared records), shared `LegacyMultiStoreSupport` deprecation bridge, deletes the `ResourceController` `store_ids=` seam, deprecates `StoreScopedResource`; multi-store sharing moves to the `spree_multi_store` extension (join tables left intact). 6.0 cleanup: enforce `null: false`, drop join tables + bridges. Paired with `6.0-channels-catalogs-b2b.md`.
- `5.6-project-layout-and-dashboard.md` — React Dashboard Developer Preview packaging + `backend/` → `api/` project layout. Implemented: `<Dashboard />` shell export from `@spree/dashboard` (source-only, relative imports only), monorepo-canonical `packages/dashboard-starter` thin host (embedded standalone into the `@spree/cli` tarball at build time via `scripts/sync-dashboard-starter.mjs` — Vendure-style, no template repo; create-spree-app delegates to the project-local `spree add dashboard`), `spree add dashboard` + create-spree-app dashboard phase (env carries only `VITE_SPREE_API_URL` — never secret keys), npm release job for `@spree/dashboard{,-ui,-core}` (0.x → `next` tag). Pending: layout rename + `detectApiDir` dual-layout CLI, `spree upgrade layout`; optional public template repo at 6.0 GA.
- `5.6-dashboard-typed-plugin-routes.md` — Plugin file routes compiled into the host's TanStack route tree: `spree.dashboard.routes` marker + virtual-route-config composition in `@spree/dashboard/vite`, `createDashboardRouter` + `<Dashboard router>` ownership inversion, typed cast-free links, cross-package collision pre-flight with package-named errors. Runtime route registry stays for dynamic/in-app cases (catch-all is lowest priority). Implemented; published-tarball spike passed.

Pending design work (drafts, no implementation yet):
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
- `5.5-admin-api-key-scopes.md` — Shopify-style `read_*`/`write_*` scopes on `Spree::ApiKey` for app authorization
- `5.5-admin-auth-cookie-refresh.md` — Admin SPA refresh token in httpOnly cookie, access token in memory, server-side logout
- `5.5-admin-customers-api.md` — Admin Customers + nested addresses/credit_cards/store_credits + CustomerGroups
- `5.5-admin-spa-csv-export.md` — Admin API ExportsController + admin-sdk + `useExport` + toolbar export button
- `5.5-agent-skills.md` — `spree/agent-skills` standalone repo: 25 Claude Code skills + `spree-expert` subagent + safety hooks, distributed via `npx skills add spree/agent-skills`

## Monorepo Structure

| Directory | Description |
|---|---|
| `spree/core` | Ruby gem — models, services, business logic (`spree_core`) |
| `spree/api` | Ruby gem — Store & Admin REST APIs (`spree_api`) |
| `spree/emails` | Ruby gem — transactional emails (optional). Deprecated in 6.0 — Next.js storefront handles consumer emails via webhooks. |
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
| `server/` | Rails app cloned from `spree/spree-starter` (.gitignored, run `pnpm server:setup`) |

## Development Server (`server/`)

One-time bootstrap (Docker required, no host Ruby): `pnpm install && pnpm server:setup`. It clones spree-starter into `server/`, boots the edge stack (monorepo gems bind-mounted via a compose overlay), and prepares + seeds the DB. Idempotent — but re-running it is a **full reset** that wipes the DB and volumes.

Day-to-day from the repo root: `pnpm server:dev` (foreground — streams web + worker logs, Ctrl+C stops them; postgres/redis stay warm) / `server:stop` (full teardown) / `server:restart` / `server:logs` / `server:console` / `server:seed` / `server:load_sample_data`. CLI commands run from `server/`: `pnpm exec spree <cmd>` (`spree migrate`, `spree console`, `spree generate model …`). `spree dev` and `spree build` refuse to run in `server/` (SPREE_PATH guard) — use the `pnpm server:*` scripts instead.

| What changed | What to run |
|---|---|
| Ruby code in `spree/*` gems | Nothing — bind-mounted, reloads on next request |
| Hosted React Dashboard at `/dashboard` (single-node test) | `pnpm server:dashboard` — rebuilds `packages/dashboard-starter/dist` with `VITE_BASE_PATH=/dashboard/`; served immediately through the monorepo mount (no restart). For dashboard *development* keep using Vite on :5173 (`cd packages/dashboard && pnpm dev`). |
| Tailwind classes in `spree/admin` templates/helpers/JS | Nothing — a watcher in the web container rebuilds the admin CSS within ~15s. If changes still don't reach the browser, delete `server/public/assets/.manifest.json` (stale precompile output that freezes asset serving) and restart web — `pnpm server:dev` boots handle this automatically. |
| New migration in a gem | Nothing — the next `pnpm server:dev` boot runs `spree:install:migrations db:prepare` (or `cd server && pnpm exec spree migrate` while running) |
| Gem dependencies (gemspec / Gemfile / starter `Gemfile.lock` drift after a pull) | Nothing — the next `pnpm server:dev` boot self-heals (`bundle check || bundle install` into the `bundle_cache` volume); while running: `cd server && pnpm exec spree bundle install` |
| Compose files / `server/.env` | `pnpm server:dev` (force-recreates web + worker) |
| `server/Dockerfile` / `.ruby-version` / starter update that breaks the image build (frozen-lockfile error) | `pnpm server:build`, then `pnpm server:dev` — the build script swaps the edge PATH lock for a RubyGems-resolved one and the next boot swaps it back |
| Meilisearch image bump ("database version … is incompatible") | `docker compose -p server rm -sf meilisearch && docker volume rm server_meilisearch_data`, boot, then `cd server && pnpm exec spree rake spree:search:reindex` |
| Broken beyond repair | `pnpm server:setup` (full reset — wipes DB + volumes) |

Backend: http://localhost:3000, admin at `/admin`, hosted React Dashboard at `/dashboard` (`spree@example.com` / `spree123`). Native no-Docker path: `pnpm server:create`, then `cd server && bin/setup && bin/dev`.

---

## General rules

- ONLY comment complex or non-obvious methods/code, do not comment every method or class, DON'T create comments noise
- Commit message body: be precise, DON'T include implementation detail, focus on the "what" and "why", not the "how"
- If n-commits are needed for a single logical change, use `git commit --fixup` for the follow-ups and `git rebase -i --autosquash` to combine into a single commit before merging
- Documentation also needs to follow the same principles — focus on the "what" and "why", not the "how". Don't include implementation details in docs. Docs should explain the feature, its purpose, and how to use it, but not how it's implemented internally.
- NEVER commit anything to main branch, always use feature/fix/chore branches for development

## Backend (Ruby)

### Architecture Principles

- All code namespaced under `Spree::` module
- Follow Rails conventions and the Rails Security Guide
- RESTful routes and action names
- CanCanCan for authorization: listings use `accessible_by(current_ability, :show)`, other actions use `authorize!`
- Always use scope fetching for security (e.g. `current_store.orders` not `Spree::Order`)
- Ransack for filtering/searching, Pagy for pagination
- Use services only when necessary — prefer standard Rails models and concerns
- DO NOT call `Spree::User` directly, use `Spree.user_class`; same for `Spree.admin_user_class`
- DO NOT put logic into controllers or serializers - this should live in models and services
- ALWAYS use Yard comments for classes and public methods, with `@param` and `@return` types
- DO NOT generate too much comment noise, be very strict and selective about what gets a comment — only non-obvious public methods, never private methods or internal helpers

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
- ALWAYS pass `class_name` and `dependent` on associations; use `dependent: :destroy_async` for high-fanout associations to offload deletion to a background job
- Include `Spree::Metafields` for custom fields support (see docs/plans/5.4-6.0-custom-fields-rename.md)
- Include `Spree::Metadata` for JSON metadata support
- ALWAYS Use string columns instead of enums
- State machines: use `state_machines-activerecord` gem, default column `status` (legacy uses `state`, see docs/plans/6.0-normalize-state-to-status.md)
- NEVER cast IDs to integer — always treat as strings (UUID support)
- Uniqueness validations: ALWAYS use `scope: spree_base_uniqueness_scope`, should be also enforced by database index
- If needed use paranoia gem for soft delete support (via `acts_as_paranoid`)
- For configuration / options always use [Model Preferences](docs/developer/customization/model-preferences.mdx)
- NEVER hardcode table names, always use `Model.table_name` in models, queries, scopes, etc.

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

- Target version: `ActiveRecord::Migration[7.2]` (Rails 7.2 support)
- No foreign key constraints
- No default values
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
- **No internal state** — never expose `cost_price`, internal status flags, soft-delete columns, audit logs, internal notes, private metadata, or admin-only relations (vendors, fulfillment providers)

**Admin serializer (back-office):**
- Always include `created_at`, `updated_at`, and `deleted_at` (when paranoid)
- Cost price, margins, internal notes, private metadata
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
    typelize cost_price: 'number | null', private_metadata: 'Record<string, unknown> | null'
    attributes :status, :cost_price, :private_metadata, :created_at, :updated_at, :deleted_at
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
- **Secret keys** (`sk_xxx`) — Admin API, `X-Spree-API-Key` header. **Server-to-server only.** Each key carries a list of [Shopify-style scopes](docs/plans/5.5-admin-api-key-scopes.md) (`read_products`, `write_orders`, etc.) that gate which endpoints it can hit. Authorization is scope-based, not CanCanCan-based.
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

**Running the admin UI locally:**

```bash
# 1. Boot a Spree backend (one terminal, from monorepo root)
pnpm server:setup       # one-time bootstrap (see "Development Server" above)
pnpm server:dev         # foreground; streams logs — Rails on http://localhost:3000

# 2. Boot the admin (separate terminal, from monorepo root)
pnpm turbo dev --filter=@spree/dashboard-starter   # http://localhost:5173 (proxies /api/* to :3000)
```

The starter is the canonical host — the same app `spree add dashboard` scaffolds — so local dev exercises the real consumer path (shell + plugin pipeline) while still hot-reloading `@spree/dashboard`/`-core`/`-ui` source through the workspace. `turbo dev` (not a bare `pnpm dev` inside the package) matters on a fresh clone: the starter's `vite.config.ts` resolves the compiled Node-side Vite entries (`@spree/dashboard/vite`, `@spree/dashboard-core/vite`) from `dist/`, and turbo's `^build` dependency produces them. After any full `pnpm build`, `cd packages/dashboard-starter && pnpm dev` works too.

`VITE_SPREE_API_URL` overrides the backend URL (default `http://localhost:3000`). Sign in with the seed admin user (`spree@example.com` / `spree123` — override at seed time with `ADMIN_EMAIL` / `ADMIN_PASSWORD`; see `spree/core/app/services/spree/seeds/admin_user.rb`).

**When implementing a new admin feature:**

1. **The Admin API is the only data source.** Never reach into Rails models or import server-rendered HTML. If a needed endpoint or attribute is missing, add it to `spree/api` first (see backend conventions above), regenerate types via the [Type Generation Pipeline](#type-generation-pipeline), then consume it from the SPA.
2. **Look at the legacy Rails admin in `spree/admin/`** for what the feature does today (data shape, business rules, edge cases) — but don't port the UX 1:1. The SPA can do better than Turbo-era full-page reloads where it meaningfully improves the experience.
3. **Follow `docs/plans/6.0-admin-spa.md`** for the three extension points (table registry, navigation registry, component injection) and the shadcn copy-paste ownership model.
4. **Wrap SDK calls in custom hooks** under `src/hooks/` (e.g. `useOrders`, `useProduct`) — never call `adminClient` directly from components.

**Translations.** Every user-visible string in `@spree/dashboard` goes through i18next — page titles, headings, table column labels, button labels, empty states, toast messages, confirm dialog copy, select option labels, badges, status text, tooltips, helper text. Never hardcode English (or any language) into JSX, into table column definitions, or into dropdown option arrays. Keys live in `packages/dashboard/src/locales/en.json` (app-specific copy) or `packages/dashboard-core/src/locales/en.json` (cross-cutting: `admin.common.*`, `admin.fields.<attribute>.<facet>`). Reach for `i18n.t(...)` at module load (table definitions) and `useTranslation().t(...)` inside components. **Schemas in `src/schemas/` hold canonical values only — never label strings.** Build `{ value, label }` pairs at render time inside the component by mapping the canonical value list against translation keys. Same goes for the legacy Rails admin: every label/hint goes through `Spree.t` / `I18n.t` against `spree/admin/config/locales/en.yml`; run `bundle exec i18n-tasks normalize` after adding keys. When adding a new translation key, ALWAYS add it to the all languages files in `packages/dashboard/src/locales/` and `packages/dashboard-core/src/locales/`.

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

**Form schemas** live in `packages/dashboard/src/schemas/<resource>.ts` when shared across 2+ files or non-trivial (~30+ lines, nested sub-schemas, companion constants); inline is fine for short single-file forms. The schema file owns the Zod schema, its inferred `FormValues` type, defaults, dropdown option arrays, and regex constants. **Don't add form↔API mappers to paper over field renames** — if you find yourself translating `ot.label → form.presentation`, fix the API instead (read/write symmetry, see "API Controllers" above). Mappers are only for pure frontend state (upload progress, transient UI bookkeeping).

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

Published packages use **Changesets** for versioning. Place changeset files in the package's `.changeset/` directory.

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

End-to-end tests for `packages/dashboard` live in `packages/dashboard/e2e/`. The global setup boots a real Rails test server (port 3010) + Vite dev (port 5174) once and seeds the DB; specs then exercise the SPA through a browser against that stack.

```bash
cd packages/dashboard && pnpm test:e2e          # full suite
cd packages/dashboard && pnpm test:e2e:ui       # Playwright UI mode (debug)
```

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
