# Spree gems — Ruby rules

Rails 8.1 engines, everything namespaced under `Spree::`. Follow Rails conventions and the Rails Security Guide; below is only what Spree does differently.

## Architecture

- Logic lives in models, concerns and workflows — not controllers or serializers. Add a service only when a model or concern won't do.
- Per-request context: `Spree::Current.store`, `.currency`, `.locale`.
- Customers and staff: `Spree.customer_class` and `Spree.admin_user_class`, never a user model constant (`Spree.user_class` is deprecated).
- Swappable classes are registered in `Spree::Dependencies` (`Spree::Dependencies.cart_add_item_workflow = 'MyApp::AddItem'`). The old `*_service` keys are deprecated, and some are no longer consulted at all.
- YARD comments (`@param`, `@return`) on classes and non-obvious public methods only; never on private helpers.
- Descriptive variable names, no abbreviations.
- Jobs that iterate over records use `ActiveJob::Continuable`.

## Models

```ruby
class Spree::Product < Spree.base_class
  include Spree::SingleStoreResource   # belongs_to :store
  include Spree::HasCustomFields
  include Spree::Metadata

  acts_as_paranoid
  publishes_lifecycle_events

  has_many :variants, class_name: 'Spree::Variant', dependent: :destroy
  validates :slug, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }
end
```

- Inherit from `Spree.base_class`. Store-owned data includes `Spree::SingleStoreResource`; only global reference data (countries, roles) and children of a parent (variants under products) go unscoped.
- Tier-1 models publish events via `publishes_lifecycle_events`.
- Always pass `class_name` and `dependent` on associations; `dependent: :destroy_async` for high-fanout ones.
- String columns, never Rails enums. **No state machines**: declare statuses with `has_status` (column `status`) and move records between them with workflows (`docs/plans/6.0-normalize-state-to-status.md`).
- Value objects use `ActiveModel::Model` + `ActiveModel::Attributes`, never `Struct` (e.g. `Spree::PickupPointOption`).
- Uniqueness validations use `scope: spree_base_uniqueness_scope`, backed by a unique index.
- Use `Model.table_name`, never a hardcoded table name. Bulk writes use `insert_all` / `upsert_all` (MySQL needs special handling).
- Options and configuration are [model preferences](../docs/developer/customization/model-preferences.mdx).
- Workflows and services write behaviour inline as named steps; they don't delegate to model business methods.

## Migrations

- New migrations target `ActiveRecord::Migration[8.1]`; existing ones keep `[7.2]`. **Never edit a migration that has shipped.**
- No foreign key constraints. `null: false` on required columns.
- No defaults on string or status columns (the creating workflow sets them); integer, decimal and boolean columns do carry defaults.
- Must run on PostgreSQL, MySQL and SQLite: guard JSON with `t.respond_to?(:jsonb) ? t.jsonb(...) : t.json(...)`. One `metadata` JSON column per table; `preferences` columns are JSON, secrets are `:password` preferences in an encrypted `secret_preferences` text column (`docs/plans/6.0-json-preferences.md`).
- Data transformations go in rake tasks, never migrations. Soft delete is `paranoia` plus a `deleted_at` column.

## API controllers (`spree/api`)

`Spree::Api::V3::ResourceController` provides Pagy, Ransack, CanCanCan, prefixed-ID lookup and HTTP caching. The `Store::`, `Admin::` and `Seller::` subclasses differ in credentials and defaults: Store is read-only unless a resource opts into writes; Admin is full CRUD by default.

- Credentials: publishable key `pk_` (Store, `X-Spree-API-Key`); secret key `sk_` (Admin, server-to-server, authorized by [scopes](../docs/plans/5.5-admin-api-key-scopes.md)); JWT bearer (customers and admin users — admin JWT is authorized by CanCanCan); guest cart token `X-Spree-Token`.
- **Scope every lookup to the store** — including incidental ones like a `reason_id` or `stock_location_id` from params. `current_store.<association>` turns a foreign id into a 404. `accessible_by` filters by role, not tenant, so it is no substitute.
- Override `model_class`, `serializer_class` (`Spree.api.<name>_serializer`), `scope` (call `super`), `collection_includes`. A resource written through a workflow overrides `create_workflow` / `update_workflow` (and `*_workflow_arguments`) instead of re-implementing the action, so it keeps the base class's record-level authorization.
- RESTful actions only; promote anything else to a nested controller.
- **Request bodies are flat and declared with `request_params`**, which drives permitting, OpenAPI and the SDK request types (`pnpm generate:params`). Never hand-write a request body in an rswag spec or a request type in an SDK. Money is `:decimal`, countries and currencies are `:country` / `:currency`. A shape used by two or more endpoints is a class in `app/request_schemas/`.
- Extensions add writable attributes with `Spree::Product.additional_permitted_attributes += [...]` (always `+=`). Override `resource_permitted_attributes`, never `permitted_attributes`, or extension attributes are dropped. Seller controllers splat `additional_seller_permitted_attributes` instead.
- `normalize_params` decodes anything shaped like a prefixed ID inside nested hashes — don't enable it on controllers that carry opaque provider values (see `Admin::PaymentMethodsController`).
- Ransack allowlists are declared on models (`whitelisted_ransackable_attributes` / `_associations` / `_scopes`). Every entry is a filter any caller can run, so an association from a global model to store-owned rows is a cross-store leak.

## Typed values — never a Ruby class name on the wire

The database stores class names; the API boundary converts them to short names (`Spree::CreditCard` → `credit_card`).

- **STI families selected by `type`** (promotion and price rules, payment methods, integrations, calculators, imports…): serialize with `Model.api_type_for(record.type)`; resolve writes with `subclassed_via` / `find_by_api_type`, which reject a class name. Override `self.api_type` to keep the value stable across a rename. Pickers read the family's `…/types` endpoint, never a hardcoded list.
- **Registry-selected strategy classes** (fulfillment, delivery-rate, tax, payout providers…): base class `extend Spree::ApiTyped`; normalize with `Spree::ApiTyped.class_name_for(registry, value)` plus an inclusion validation; serialize with `api_type_attributes`; load with `Spree::ApiTyped.registered_class` — never `constantize` a stored string. Every new family gets a registry.
- **Polymorphic columns**: serialize with `Spree::Base.polymorphic_api_type`, accept with `polymorphic_type_for(value, candidates)`. The base controller translates `type_*` filters.
- Never special-case old class names; upgrade tasks migrate stored data.

## Serializers (Alba)

Admin serializers extend Store serializers; every serializer an Admin one references has its own Admin counterpart.

- **Store** (customer-facing): public data and display values only — no timestamps, `metadata`, cost prices, internal statuses or back-office relations.
- **Admin**: adds `created_at`, `updated_at`, `deleted_at` (when paranoid), `metadata` and back-office fields.
- Associations are their own serializers, never hand-built hashes. Keep serializers lean; logic goes on the model. Never use `typelize_from`.
- An attribute block only reads: a method call, a format or a one-line fallback. Branching, lookups and queries go on the model (`user.status`, `user.invited_by(store)`), where they are tested once and reused outside the API.
- Value lists: **closed** lists use `enum:` + `enum_type_name:` and are added to `Typelizer::OpenEnums::CLOSED_LIST_NAMES`; **open** lists (`has_status`, kinds extensions can add) use `enum_type_name:` alone; registry-driven `type` attributes stay `:string` with a `comment:` listing the built-ins. Both named kinds are generated into `@spree/core`.
- Deprecated fields are marked (`deprecated: 'Use X. Removed in 6.1.'`), not just described.
- After a serializer change run the type pipeline: `cd spree/api && bundle exec rake typelizer:generate`, then `pnpm generate:zod` from the root (the Lefthook pre-commit hook does both), then integration specs and `bundle exec rake rswag:specs:swaggerize`. Restart Rails — Alba caches definitions at boot.

## Events and webhooks

`record.publish_event('order.completed')`; subscribers in `app/subscribers/spree/` subclass `Spree::Subscriber`. Payloads use Store serializers only — never a hand-built hash or an Admin serializer; extras go in `metadata` (`docs/plans/6.0-typed-webhook-events.md`).

## Emails (Liquid + MJML)

See `docs/plans/6.0-liquid-mjml-emails.md` and `docs/developer/customization/emails.mdx`.

- Templates are `app/views/spree/<mailer>/<action>.liquid` (that path is a public key), MJML with front-matter subject; never ERB.
- Mailers inherit `Spree::BaseMailer`, wrap sends in `with_store_locale`, and pass data through `email_data(record, Spree::Emails::XyzSerializer)` — templates never touch models. Every record a customer email serializes has its own serializer under `spree/emails/app/serializers/spree/emails/`.
- Never serialize a token: build reset, invitation and download URLs in the mailer.
- Colors and fonts come from `store.branding`.
- A new or changed customer email updates `docs/developer/customization/email-variables.mdx`, `spree/emails/spec/mailers/spree/rendered_emails_spec.rb` and gets a mailer preview. A new customer email is registered in `Spree.editable_email_templates` with a sample builder; staff and seller emails never are.

## Money, time and translations

- Money: `BigDecimal` only — no `.to_f`, `Float()` or float literals on amounts. Use `Spree::Money::Rounding`: `to_currency` to round (only when persisting, serializing or calling a gateway), `to_minor_units` / `from_minor_units`, `parse_canonical` for request input (canonical decimal strings, no locale parsing), `format` for output. A third party that needs a JSON number gets `.to_f` once, with a comment.
- Store dates use the store's zone: `Time.find_zone(store.preferred_timezone) || Time.zone`. Never `Time.zone.parse` operator input meant as a fixed instant — use `iso8601`.
- `I18n.t('spree.<key>')` with the full key (`Spree.t` is deprecated). Keys live in `config/locales/en.yml`. Before removing a key `i18n-tasks unused` reports, check it isn't built dynamically.

## Third-party APIs

Use the official gem when one exists, record tests with VCR (filter secrets), and call through timeouts and retries — slow calls go to jobs. Errors reaching the API consumer must name what to fix in the provider's own words (surface the structured error, not the summary), and a catch-all `rescue` must never swallow a deliberate, well-worded refusal.

## Tests

- RSpec + FactoryBot (factories in `lib/spree/testing_support/factories/`). No tests for standard Rails validations; fold new cases into existing `describe` blocks.
- Controller specs (`render_views`) cover edge cases; rswag integration specs cover only the happy path and simple 422s that feed the OpenAPI examples.
- Every API request in specs is checked for N+1 queries by Prosopite. Fix the query at the reported line (`collection_includes`, a loaded association, one grouped query) — never a per-record `count`, never disabling the guard. Every index spec includes `it_behaves_like 'a list without N+1 queries'` with at least two records.
- Never update or save the shared `@default_store`; stub what the code reads or build another store. Registries and hooks a spec changes must be restored afterwards.
- OpenAPI files in `docs/api-reference/` are generated (`bundle exec rake rswag:specs:swaggerize`) and deterministic: the clock is frozen, so a factory whose record must already be active needs a start in the past. Never edit them by hand; a diff means the API changed.
