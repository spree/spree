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
- `6.0-admin-spa.md` — React admin architecture, plugin system
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


- `5.4-disjunctive-option-faceting.md` — Per-option-type filter params with disjunctive facet counts (OR within option type, AND across)
- `5.4-option-type-enhancements.md` — Add `kind` (dropdown/color_swatch/buttons) to OptionType, `color_code` + `image` to OptionValue for swatch support
- `5.4-6.0-custom-fields-rename.md` — Rename Metafields → Custom Fields (5.4 API bridge + 6.0 model rename)
- `5.4-centralized-translations-admin.md` — Centralized Translations admin page under Products, overview grid + bulk CSV import/export

Completed plans:
- `5.4-store-api-bridges.md` — Bridge 6.0 naming into 5.4 Store API (implemented, PR #13782)
- `spree-starter-and-create-spree-app.md` — Replace monorepo server/ with spree-starter template repo

## Monorepo Structure

| Directory | Description |
|---|---|
| `spree/core` | Ruby gem — models, services, business logic (`spree_core`) |
| `spree/api` | Ruby gem — Store & Admin REST APIs (`spree_api`) |
| `spree/emails` | Ruby gem — transactional emails (`spree_emails`, optional) |
| `packages/sdk` | `@spree/sdk` — TypeScript Store API client |
| `packages/admin-sdk` | `@spree/admin-sdk` — TypeScript Admin API client (private) |
| `packages/sdk-core` | `@spree/sdk-core` — shared HTTP/retry/error layer (private) |
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
- Always pass `class_name` and `dependent` on associations
- Include `Spree::Metafields` for metadata support
- Use string columns instead of enums
- State machines: use `state_machines-activerecord` gem, default column `status` (legacy uses `state`)
- Never cast IDs to integer — always treat as strings (UUID support)
- Uniqueness validations: always use `scope: spree_base_uniqueness_scope`

```ruby
class Spree::Product < Spree.base_class
  include Spree::Metafields

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

#### Hierarchy

- **Base:** `Spree::Api::V3::ResourceController` — CRUD, pagination (Pagy), Ransack, CanCanCan, prefixed ID lookups, HTTP caching
- **Store API:** `Spree::Api::V3::Store::ResourceController` — publishable API key auth
- **Admin API:** `Spree::Api::V3::Admin::ResourceController` — secret API key auth

#### Key overridable methods

`model_class`, `serializer_class` (use `Spree.api.serializer_name`), `scope` (call `super` and chain), `find_resource`, `permitted_params`, `collection_includes`

#### Flat request/response structure

API v3 uses flat params — no nested Rails-style wrapping. The base controller auto-infers from `Spree::PermittedAttributes`:

```ruby
# ✅ Flat params
def permitted_params
  params.permit(Spree::PermittedAttributes.product_attributes)
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

Located in `api/app/serializers/spree/api/v3/`. Store and Admin APIs have separate serializers; Admin extends Store:

```ruby
# Store serializer
module Spree::Api::V3
  class ProductSerializer < BaseSerializer
    typelize purchasable: :boolean, in_stock: :boolean, price: 'number | null'
    attributes :id, :name, :description, :slug, :price
  end
end

# Admin serializer — extends store
module Spree::Api::V3::Admin
  class ProductSerializer < V3::ProductSerializer
    typelize cost_price: 'number | null', private_metadata: 'Record<string, unknown> | null'
    attributes :status, :cost_price, :private_metadata
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
    subscribes_to 'order.complete'

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

- **Publishable keys** (`pk_xxx`) — Store API, via `X-Spree-API-Key` header
- **Secret keys** (`sk_xxx`) — Admin API, via `X-Spree-API-Key` header
- **JWT tokens** — user auth, via `Authorization: Bearer <token>` header
- **Guest cart tokens** — via `X-Spree-Token` header

### Dependencies System

Register swappable services in `Spree::Dependencies`:

```ruby
Spree::Dependencies.cart_add_item_service = 'Spree::Cart::AddItem'
```

### Security

- CanCanCan permission checks on all actions
- `Spree::PermittedAttributes` for parameter allowlists
- Use `Spree.user_class` / `Spree.admin_user_class` — never reference user models directly
- Use `spree.` route engine prefix in views and controllers

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
```

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

Same patterns as `@spree/sdk` but for the Admin API. Supports both secret key (server-to-server) and JWT (admin SPA) authentication. Private package.

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
