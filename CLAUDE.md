# Spree Commerce — Development Rules

## Plans & Architecture Decisions

All feature plans live in `docs/plans/` using the template at `docs/plans/_template.md`. Never create plans elsewhere.

When proposing significant architectural changes:

1. Check existing plans in `docs/plans/` for conflicts
2. Create or update a plan using the template before implementing
3. Pay special attention to "Constraints on Current Work" sections — these apply even when you're not implementing that plan directly

Use `/project:create-plan` and `/project:update-plan` for plan management, and `/project:implement-plan <plan>` to deliver a plan end to end (open questions → implementation → reviews → running QA environment → pull request).

## Monorepo Structure

| Directory | Description |
| --- | --- |
| `spree/core` | Ruby gem — models, services, business logic (`spree_core`) |
| `spree/api` | Ruby gem — Store & Admin REST APIs (`spree_api`) |
| `spree/emails` | Ruby gem — transactional emails (optional). Rebuilt + modernized in 5.6. The default email stack for installations without a storefront app (e.g. mobile apps); headless storefronts may instead own consumer emails via webhooks. |
| `spree/providers/easypost` | Ruby gem (`spree_easypost`, optional) — reference `DeliveryRateProvider` + `FulfillmentProvider`: live EasyPost rates, label purchase/refund, credentials via `SpreeEasyPost::Integration`. Provider gems live under `spree/providers/` (stripe/adyen/avalara land there too); gem names stay flat. |
| `spree/providers/meilisearch` | Ruby gem (`spree_meilisearch`, optional) — `SpreeMeilisearch::SearchProvider` + `SpreeMeilisearch::ProductPresenter`: typo-tolerant product search, disjunctive facets and merchant-ordered grouping pages. Extracted from core in 6.0; credentials come from `MEILISEARCH_URL`/`MEILISEARCH_API_KEY` (index is installation-wide infrastructure, not a per-store `Integration`). |
| `spree/dashboard` | Ruby gem (`spree_dashboard`, optional) — hosts a built React Dashboard at `/dashboard` and Seller Panel at `/seller` from `Spree::Dashboard.dist_path` / `SPREE_DASHBOARD_DIST_PATH` (single-node topology). Successor slot to `spree_admin` at 6.0. |
| `packages/dashboard` | `@spree/dashboard` — React SPA admin dashboard (Spree 6.0, replaces `spree/admin`). The deployable app shell, routes, schemas, resource hooks, locales. |
| `packages/dashboard-ui` | `@spree/dashboard-ui` — design system. Shadcn primitives + headless composed components + tokens. Source-only; consumer compiles via Vite/Tailwind. **Components are headless: data comes via props, no provider/hook imports.** |
| `packages/dashboard-core` | `@spree/dashboard-core` — framework. Registries (table, nav, slot, settings-nav), providers (auth, permission, store, theme), generic infra hooks, admin SDK client singleton, `defineDashboardPlugin` facade. The extension API for plugin authors. |
| `packages/dashboard-starter` | `@spree/dashboard-starter` — thin host app consuming `<Dashboard />` from `@spree/dashboard`; canonical source of the `spree/dashboard-starter` template repo (synced on release). Doubles as the in-repo consumer test for the plugin pipeline. |
| `packages/seller-dashboard` | `@spree/seller-dashboard` — React SPA seller panel for marketplace dpeloyments. The deployable app shell, routes, schemas, resource hooks, locales. |
| `packages/seller-dashboard-starter` | `@spree/seller-dashboard-starter` — thin host app consuming `<SellerDashboard />` from `@spree/seller-dashboard`; canonical source of the `spree/seller-dashboard-starter` template repo (synced on release). Doubles as the in-repo consumer test for the plugin pipeline. |
| `packages/sdk` | `@spree/sdk` — TypeScript Store API client |
| `packages/admin-sdk` | `@spree/admin-sdk` — TypeScript Admin API client |
| `packages/seller-sdk` | `@spree/seller-sdk` — TypeScript Seller API client |
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
- DRY - Don't Repeat Yourself - before adding a new feature or functionality, check if it already exists in the codebase. If it does, reuse it instead of duplicating code. This helps to keep the codebase clean and maintainable, our goal is to minimize the number of lines of code, not to expand it without control
- Be Paranoid - always assume that the code you are writing will be used in unexpected ways, and that users may try to break it. Security is another important aspect of development, and we should always be mindful of potential vulnerabilities and attack vectors. Always validate user input, sanitize data, and follow best practices for secure coding. Use tools like static analysis, code reviews, and penetration testing to identify and fix security issues before they become a problem. Always keep security in mind when designing new features or making changes to existing code.
- Seller Panel and Admin Dashboard - dashboard is the reference, when adding features to Seller panel extract code to re-usable components in dashboard, move it to dashboard-ui/dashboard-core, import it in Seller Panel

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

### 3rd party APIs

When working on integrating 3rd party APIs, SDKs, or webhooks, follow these guidelines:
- always use official ruby gems or SDKs if available, otherwise use Faraday or Ruby HTTP::Net for HTTP requests
- tests should use VCR and record real API responses for replay in CI, remember to filter sensitive data from the recordings via VCR config filter
- when handling errors expose them in a structured way to the API consumer, don't fully swallow errors or return generic 500s - Errors must name what to fix, in the service's own words, eg. EasyPost's summary said "Missing required parameter" while the useful end_shipper.address.phone sat in the structured errors array
- A catch-all rescue must not swallow a deliberate refusal, eg. so the "unexpected failure means no label" rescue was silently eating every carefully worded message
- Always use timeout, retries with exponential backoff, and circuit breaker patterns when calling 3rd party APIs. Never block the main thread for long-running API calls; use background jobs for async processing

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
- Fold specs into the existing describe blocks, use context blocks for different scenarios, NEVER create new test files for a single new scenario unless it is a completely new feature

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
