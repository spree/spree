# Spree Commerce — Development Rules

## Plans & Architecture Decisions

All feature plans live in `docs/plans/` using the template at `docs/plans/_template.md`. Never create plans elsewhere.

When proposing significant architectural changes:
1. Check existing plans in `docs/plans/` for conflicts
2. Create or update a plan using the template before implementing
3. Pay special attention to "Constraints on Current Work" sections — these apply even when you're not implementing that plan directly

Use `/project:create-plan` and `/project:update-plan` for plan management.

Current plans:
- `6.0-cart-order-split.md` — Cart/Order model separation, polymorphic LineItem
- `6.0-admin-api.md` — Admin REST API conventions, auth, endpoint list (~300 endpoints)
- `6.0-admin-spa.md` — React admin architecture, extension points, table registry
- `6.0-product-types.md` — Prototype → ProductType rename, MetafieldDefinition schema enforcement
- `6.0-remove-master-variant.md` — Eliminate is_master, add default_variant_id FK on Product
- `6.0-split-adjustments.md` — Replace polymorphic Adjustment with TaxLine, Discount, Fee
- `6.0-stock-reservations.md` — Time-limited stock reservations during checkout
- `6.0-typed-stock-movements.md` — Replace generic StockMovement with typed kinds + concrete FKs
- `6.0-normalize-state-to-status.md` — Rename state → status on Payment, Shipment, InventoryUnit, ReturnAuthorization, GiftCard
- `6.0-fulfillment-and-delivery.md` — Shipment→Fulfillment, ShippingMethod→DeliveryMethod, drop ShippingCategory, FulfillmentProvider strategy, pickup (merchant StockLocation) + pickup_point (third-party PickupPointProvider)
- `6.0-returns-exchanges-claims.md` — First-class Return, Exchange, Claim models replacing ReturnAuthorization/Reimbursement chain
- `6.0-channels-catalogs-b2b.md` — Channel, Catalog, ProductListing (replaces StoreProduct), Company/CompanyLocation/CompanyContact for B2B
- `6.0-platform-auth.md` — Drop Devise, own auth stack, User→Customer/Staff rename
- `5.4-search-provider.md` — Pluggable SearchProvider interface (5.4: Database + Meilisearch, 6.0: MetafieldDefinition faceting)
- `6.0-tax-provider.md` — Per-Market TaxProvider, replaces TaxRate.adjust + Calculator, drop Zone model (TaxRate gets direct country/state FKs)
- `6.0-delivery-rate-provider.md` — Per-DeliveryMethod DeliveryRateProvider, replaces Estimator + Calculator, DeliveryZone with postal code support
- `6.0-rich-text-descriptions.md` — Drop ActionText storage, store HTML in text columns, sanitize on write, serve `description` + `description_html` in API
- `5.4-store-api-naming-standardization.md` — Standardize API naming against industry (address fields, discounts, customer_note, label, brand/last4, etc.)
- `5.4-6.0-eu-legal-compliance.md` — GDPR (data export/anonymization, consent timestamps), Omnibus (PriceHistory, lowest-in-30-days), Consumer Rights (withdrawal period). Core primitives + enterprise hooks.
- `6.0-order-routing.md` — Two-tier extension: pluggable `Spree::OrderRouting::Strategy::Base` (whole algorithms) + STI subclasses of `Spree::OrderRoutingRule` (signals consumed by `Rules` strategy). Adds `Spree::Order.preferred_stock_location_id`, `Spree::Order.channel_id` (FK replacing the deprecated string column), `Spree::Channel`, `Spree::OrderRoutingRule`. Phase 1 (5.5) ships channel-scoped rules + minimal `Spree::Channel`; Phase 2 (6.0) layers ProductListing/Catalog/Company on top via `6.0-channels-catalogs-b2b.md`.
- `5.5-6.0-order-cancellation-and-approval.md` — First-class `OrderCancellation` + `OrderApproval` models, capture reasons/restock/refund decisions, polymorphic actor; 6.0 drops denormalized columns
- `5.5-admin-api-key-scopes.md` — Shopify-style `read_*`/`write_*` scopes on `Spree::ApiKey` for Admin API authorization (apps), independent of CanCanCan (which stays for JWT users)
- `5.4-disjunctive-option-faceting.md` — Per-option-type filter params with disjunctive facet counts (OR within option type, AND across)
- `5.4-option-type-enhancements.md` — Add `kind` (dropdown/color_swatch/buttons) to OptionType, `color_code` + `image` to OptionValue for swatch support
- `5.4-6.0-custom-fields-rename.md` — Rename Metafields → Custom Fields (5.4 API bridge + 6.0 model rename)
- `5.4-centralized-translations-admin.md` — Centralized Translations admin page under Products, overview grid + bulk CSV import/export
- `5.4-metafield-translations.md` — Translate MetafieldDefinition names + Metafield text values (ShortText, LongText, RichText) via Mobility translation tables
- `5.5-admin-auth-cookie-refresh.md` — Move admin SPA refresh token to httpOnly cookie, access token in memory, double-submit CSRF, server-side logout that destroys RefreshToken row. Breaking change shipped as a single coordinated bump (admin-sdk is unreleased)
- `5.5-admin-spa-csv-export.md` — Reuse existing `Spree::Export` infra; add Admin API CRUD + `client.exports` SDK + toolbar button/modal + polling flow on Products/Orders/Customers index pages. Filters round-trip via Ransack JSON; download via short-lived signed Blob URL

Completed plans:
- `5.4-store-api-bridges.md` — Bridge 6.0 naming into 5.4 Store API (implemented, PR #13782)
- `spree-starter-and-create-spree-app.md` — Replace monorepo server/ with spree-starter template repo

## Monorepo Structure

| Directory | Description |
|---|---|
| `spree/core` | Ruby gem — models, services, business logic (`spree_core`) |
| `spree/api` | Ruby gem — Store & Admin REST APIs (`spree_api`) |
| `spree/emails` | Ruby gem — transactional emails (optional). Deprecated in 6.0 — Next.js storefront handles consumer emails via webhooks. |
| `packages/admin` | `@spree/admin` — React SPA admin dashboard (Spree 6.0, replaces `spree/admin`) |
| `packages/sdk` | `@spree/sdk` — TypeScript Store API client |
| `packages/admin-sdk` | `@spree/admin-sdk` — TypeScript Admin API client (Developer Preview) |
| `packages/sdk-core` | `@spree/sdk-core` — shared HTTP/retry/error layer (private internal) |
| `packages/cli` | `@spree/cli` — Docker-based project management CLI |
| `packages/create-spree-app` | `create-spree-app` — project scaffolding |
| `server/` | Rails app cloned from `spree/spree-starter` (.gitignored, run `pnpm server:setup`) |

---

## Backend (Ruby)

### Architecture Principles

- All code namespaced under `Spree::` module
- Follow Rails conventions and the Rails Security Guide
- RESTful routes and action names
- CanCanCan for authorization: listings use `accessible_by(current_ability, :show)`, other actions use `authorize!`
- Always use scope fetching for security (e.g. `current_store.orders` not `Spree::Order`)
- Ransack for filtering/searching, Pagy for pagination
- Business logic belongs in models and concerns, not controllers
- Use services only when necessary — prefer standard Rails models and concerns
- Do not call `Spree::User` directly, use `Spree.user_class`; same for `Spree.admin_user_class`

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

- Inherit from `Spree.base_class`
- Always pass `class_name` and `dependent` on associations; use `dependent: :destroy_async` for high-fanout associations to offload deletion to a background job
- Include `Spree::Metafields` for custom fields support (see docs/plans/5.4-6.0-custom-fields-rename.md)
- Include `Spree::Metadata` for JSON metadata support
- Use string columns instead of enums
- State machines: use `state_machines-activerecord` gem, default column `status` (legacy uses `state`, see docs/plans/6.0-normalize-state-to-status.md)
- Never cast IDs to integer — always treat as strings (UUID support)
- Uniqueness validations: always use `scope: spree_base_uniqueness_scope`, should be also enforced by database index
- If needed use paranoia gem for soft delete support (via `acts_as_paranoid`)
- For configuration / options always use [Model Preferences](docs/developer/customization/model-preferences.mdx)

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

### @spree/admin — Admin UI (React SPA)

The Spree 6.0 admin dashboard. A Vite-built React SPA that replaces the legacy Rails `spree/admin` engine entirely. See [`packages/admin/README.md`](packages/admin/README.md) for the full tech stack, project structure, and architecture (auth flow, permissions, multi-store, extension points). Architecture decisions live in `docs/plans/6.0-admin-spa.md`.

**Tech stack at a glance:** Vite, TanStack Router (file-based, type-safe), TanStack Query, React Hook Form + Zod, shadcn/ui + Base UI + Tailwind, Biome, Vitest. All API calls go through `@spree/admin-sdk`.

**Running the admin UI locally:**

```bash
# 1. Boot a Spree backend (one terminal, from monorepo root)
pnpm server:setup       # one-time: clones spree-starter into ./server
pnpm server:dev         # Rails on http://localhost:3000

# 2. Boot the admin (separate terminal)
cd packages/admin
pnpm dev                # http://localhost:5173 (proxies /api/* to :3000)
```

`VITE_SPREE_API_URL` overrides the backend URL for both dev and build (defaults to `http://localhost:3000`). Sign in with the seed admin user (`admin@example.com` / `spree123` by default — check your server's `db/seeds.rb`).

**When implementing a new admin feature:**

1. **Look at the legacy Rails admin in `spree/admin/`** for guidance on what the feature does today (data shape, business rules, edge cases). It's a useful reference for "what does this screen actually need to do."
2. **Don't port the UX 1:1.** The legacy admin is Rails + Turbo, which constrained UX choices around server round-trips, full page navigations, and form submissions. The React SPA can do better — inline editing, optimistic updates, multi-step flows without page reloads, modal-driven workflows, real-time validation, drag-and-drop, virtualized lists. Use those patterns where they meaningfully improve the experience.
3. **The Admin API is the only data source.** Never reach into Rails models or import server-rendered HTML.
4. **Follow `docs/plans/6.0-admin-spa.md`** for the three extension points (table registry, navigation registry, component injection) and the shadcn copy-paste ownership model.
5. **Wrap SDK calls in custom hooks** under `src/hooks/` (e.g., `useOrders`, `useProduct`) — never call `adminClient` directly from components.

If a needed Admin API endpoint or attribute is missing, **add it to `spree/api` first** (see backend conventions above), regenerate types via the [Type Generation Pipeline](#type-generation-pipeline), then consume it from the SPA.

**Base UI vs Radix — `<Select>` does not auto-render labels.** The admin SPA's `<Select>` wraps **Base UI** (`@base-ui/react/select`), not Radix. Unlike Radix, Base UI's `<Select.Value />` defaults to rendering the raw selected `value` (e.g. the ISO code, the slug, the prefixed ID) instead of the matching `<SelectItem>`'s children. A bare `<SelectValue />` next to `<SelectItem value="warehouse">Warehouse</SelectItem>` will display `warehouse`, not `Warehouse`.

There are two correct ways to make the trigger show the label:

1. **Pass `items` to `<Select>` (preferred when option labels are static).** Base UI resolves the trigger label from the items array automatically:
   ```tsx
   const KIND_OPTIONS = [{ value: 'warehouse', label: 'Warehouse' }, ...] as const

   <Select items={KIND_OPTIONS} value={...} onValueChange={...}>
     <SelectTrigger><SelectValue /></SelectTrigger>
     <SelectContent>
       {KIND_OPTIONS.map((o) => <SelectItem key={o.value} value={o.value}>{o.label}</SelectItem>)}
     </SelectContent>
   </Select>
   ```
2. **Use the `<SelectValue>` children render-prop (when labels are dynamic, e.g. fetched options).** Base UI calls the function with the current value:
   ```tsx
   <SelectValue>
     {(value) => roles.find((r) => r.id === value)?.name ?? (value as string)}
   </SelectValue>
   ```

For free-text **searchable** pickers, prefer `<Combobox>` over `<Select>` — see `components/spree/country-state-fields.tsx` for the country/state pattern.

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
- Pragmatic — no tests for standard Rails validations, only custom ones
- Controller specs: always add `render_views`, use `stub_authorization!` for auth
- Time-based tests: use `Timecop`
- Don't over-engineer or repeat tests

### Frontend (TypeScript — Vitest)

```bash
cd packages/sdk && pnpm test       # SDK tests (uses MSW for HTTP mocking)
```
