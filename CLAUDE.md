# Claude Code Rules for Spree Commerce Development

## General Development Guidelines

### Framework & Architecture

- Spree is built on Ruby on Rails and follows MVC architecture
- All Spree code must be namespaced under `Spree::` module
- Spree is distributed as Rails engines with separate packages:
  - **Core packages (required):** `spree_core` (models, services, business logic), `spree_api` (Storefront API, Platform API, Webhooks)
  - **Optional packages:** `spree_admin` (admin dashboard), `spree_storefront` (Rails storefront), `spree_emails` (transactional emails), `spree_page_builder` (visual page builder), `spree_sample` (sample data), `spree_dev_tools` (development/testing utilities)
- Most users run Spree in headless mode with custom frontends using the Storefront API
- Follow Rails conventions and the Rails Security Guide
- Prefer Rails idioms and standard patterns over custom solutions
- Use RESTful action names

### Code Organization

- Place all models in `app/models/spree/` directory
- Place all controllers in `app/controllers/spree/` directory  
- Place all services in `app/services/spree/` directory
- Place all mailers in `app/mailers/spree/` directory
- Place all API serializers in `app/serializers/spree/` directory
- Place all helpers in `app/helpers/spree/` directory
- Place all jobs in `app/jobs/spree/` directory
- Place all presenters in `app/presenters/spree/` directory
- Use consistent file naming: `spree/product.rb` for `Spree::Product` class
- Group related functionality into concerns when appropriate
- Do not call `Spree::User` directly, use `Spree.user_class` instead
- Do not call `Spree::AdminUser` directly, use `Spree.admin_user_class` instead

### Spree::Current class

`Spree::Current` is a class that provides access to the current store, currency, and locale. It is available in models, controllers, jobs and services. Each value is set per request.

`Spree::Current.store` — current store
`Spree::Current.currency` — current currency
`Spree::Current.locale` — current locale

## Naming Conventions & Structure

### Classes & Modules

```ruby
# ✅ Correct naming
module Spree
  class Product < Spree.base_class
  end
end

module Spree
  module Admin
    class ProductsController < ResourceController
    end
  end
end

# ❌ Incorrect - missing namespace
class Product < ApplicationRecord
end
```

Always inherit from `Spree.base_class` when creating models.

### File Paths

- Models: `app/models/spree/product.rb`
- Controllers: `app/controllers/spree/admin/products_controller.rb`

## Model Development

### Model Patterns

- Use ActiveRecord associations appropriately, always pass `class_name` and `dependent` options
- Implement concerns for shared functionality
- Use scopes for reusable query patterns
- Include `Spree::Metafields` concern for models that need metadata support
- Don't use enums, use string columns instead
- For models that require state machine, please use https://github.com/state-machines/state_machines-activerecord gem, default column should be `status`, legacy models use `state`
- Don't ever cast IDs to integer, we need to support also UUIDs so please always treat IDs as strings

```ruby
# ✅ Good model structure
class Spree::Product < Spree.base_class
  include Spree::Metafields
  
  has_many :variants, class_name: 'Spree::Variant', dependent: :destroy
  
  scope :available, -> { where(available_on: ..Time.current) }
  
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }
end
```

For uniqueness validation, always use `scope: spree_base_uniqueness_scope`

## Controller Development

### Controller Inheritance

- Admin controllers inherit from `Spree::Admin::ResourceController` which handles most of CRUD operations
- Store API controllers inherit from `Spree::Api::V3::Store::ResourceController`
- Storefront controllers inherit from `Spree::StoreController`

### Parameter Handling

- Always use strong parameters
- Always use `Spree::PermittedAttributes` to define allowed parameters for each resource

## API Development

Spree API v3 provides RESTful endpoints organized into two scopes:

- **Store API** (`/api/v3/`) - Customer-facing endpoints for cart, checkout, products, and accounts
- **Admin API** (`/api/v3/admin/`) - Administrative endpoints for managing orders, products, and store settings

### Prefixed IDs

All API v3 responses use Stripe-style prefixed IDs (e.g., `prod_86Rf07xd4z`, `variant_k5nR8xLq`, `or_m3Rp9wXz`). This is a critical convention:

- **Always return prefixed IDs** in API responses — never expose raw integer/UUID IDs
- **Always accept prefixed IDs** in API request parameters (e.g., `variant_id`, `product_id`)
- The `BaseSerializer` automatically converts the primary `id` attribute to a prefixed ID
- For association IDs in serializers, explicitly use `object.association&.prefixed_id`
- In controllers, use `find_by_prefix_id!` for lookups — the base `ResourceController` does this automatically for `params[:id]`

```ruby
# ✅ Correct - serializer returning prefixed IDs for associations
attribute :variant_id do |line_item|
  line_item.variant&.prefixed_id
end

# ✅ Correct - controller looking up by prefixed ID
@variant = current_store.variants.find_by_prefix_id!(params[:variant_id])

# ❌ Incorrect - exposing raw IDs in API
attribute :variant_id  # This would return the raw integer ID
```

### Flat Request/Response Structure

API v3 uses a **flat parameter structure** — no nested Rails-style params wrapping:

```ruby
# ✅ Correct - flat params (API v3 style)
def permitted_params
  params.permit(Spree::PermittedAttributes.product_attributes)
end

# ❌ Incorrect - nested Rails params (not used in API v3)
def permitted_params
  params.require(:product).permit(:name, :description, :slug)
end
```

The base `ResourceController` automatically infers permitted attributes from `Spree::PermittedAttributes`:

```ruby
# Automatically maps ProductsController -> Spree::PermittedAttributes.product_attributes
def permitted_params
  params.permit(permitted_attributes)
end
```

Responses are also flat JSON objects, not wrapped in a root key.

### API Controllers

#### Controller Hierarchy

- **Base:** `Spree::Api::V3::ResourceController` — provides standard CRUD, pagination (pagy), Ransack filtering, authorization (CanCanCan), prefixed ID lookups, and HTTP caching
- **Store API:** `Spree::Api::V3::Store::ResourceController` — adds publishable API key authentication
- **Admin API:** `Spree::Api::V3::Admin::ResourceController` — adds secret API key authentication

```ruby
# ✅ Store API controller
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

#### Key ResourceController Methods

Override these in subclasses to customize behavior:

- `model_class` — the ActiveRecord model class
- `serializer_class` — the Alba serializer (use `Spree.api.serializer_name` for configurable references)
- `scope` — base scope for queries (call `super` and chain)
- `find_resource` — resource lookup (defaults to `scope.find_by_prefix_id!(params[:id])`)
- `permitted_params` — allowed request parameters
- `collection_includes` — eager loading associations for index action

### Serializers

API v3 uses [Alba serializers](https://github.com/okuramasafumi/alba) located in `api/app/serializers/spree/api/v3/`. We have separate serializers for Store and Admin APIs:

- **Store serializers** (`app/serializers/spree/api/v3/`) - Customer-facing, limited data
- **Admin serializers** (`app/serializers/spree/api/v3/admin/`) - Full access, extends store serializers

Admin serializers inherit from store serializers and add additional fields.

```ruby
# Store serializer - customer-facing
module Spree::Api::V3
  class ProductSerializer < BaseSerializer
    typelize purchasable: :boolean, in_stock: :boolean, price: 'number | null'

    attributes :id, :name, :description, :slug, :price
  end
end

# Admin serializer - extends store with admin-only fields
module Spree::Api::V3::Admin
  class ProductSerializer < V3::ProductSerializer
    typelize cost_price: 'number | null', private_metadata: 'Record<string, unknown> | null'

    attributes :status, :cost_price, :private_metadata
  end
end
```

Never use `typelize_from` in serializers — this causes serializers to connect to the database.

### Serializer DSL

- `typelize attr: :type` — define types for computed/delegated attributes
- Use `Spree.api.serializer_name` for configurable serializer references
- Customize serializers by inheriting from the default and configuring via `Spree.api`:

```ruby
# Custom serializer
module MyApp
  class ProductSerializer < Spree::Api::V3::ProductSerializer
    attribute :custom_field
  end
end

# Configure in initializer
Spree.api.product_serializer = 'MyApp::ProductSerializer'
```

### TypeScript Type Generation

We use [typelizer](https://github.com/skryukov/typelizer) to generate TypeScript types from Alba serializers:

- Types are generated to `sdk/src/types/generated/`
- Store types: `StoreProduct`, `StoreOrder`, etc.
- Admin types: `AdminProduct`, `AdminOrder`, etc.
- Run `bundle exec rake typelizer:generate` to regenerate types every time you make changes to serializers

### API Authentication

- **Publishable API keys** (`spree_pk_xxx`) — used for Store API, passed via `Authorization: Bearer` header
- **Secret API keys** (`spree_sk_xxx`) — used for Admin API, passed via `Authorization: Bearer` header
- **User authentication** — JWT tokens, passed via `Authorization: Bearer <token>` header
- **Guest cart tokens** — passed via `X-Spree-Order-Token` header for guest checkout

```ruby
# Creating API keys
store_api_key = Spree::ApiKey.create!(name: 'My Storefront', key_type: :publishable, store: Spree::Current.store)
admin_api_key = Spree::ApiKey.create!(name: 'Admin Integration', key_type: :secret, store: Spree::Current.store)
```

### OpenAPI generation

Store API Open API specitication is generated using rswag gem, and stored in `docs/api-reference/store.yaml` file.
To generate the OpenAPI specification, run the following command:

```bash
bundle exec rake rswag:specs:swaggerize
```

It will use Rspec integration tests from `backend/engines/api/spec/integration`.

## Events System

When adding new functionality that other parts of the system (or external integrations) might need to react to, fire events using Spree's event system:

```ruby
order.publish_event('order.completed')
```

Place subscriber classes in `app/subscribers/spree/` directory:

```ruby app/subscribers/spree/order_completed_subscriber.rb
module Spree
  class OrderCompletedSubscriber < Spree::Subscriber
    subscribes_to 'order.complete'

    def handle(event)
      order_id = event.payload['id']
      order = Spree::Order.find_by_prefix_id(order_id)
      return unless order

      # Your custom logic here
      ExternalService.notify_order_placed(order)
    end
  end
end
```

For new models that publish events, please add `publishes_lifecycle_events` concern to the model.

You also need to create an event serializer for the model, see [Events](docs/developer/core-concepts/events.mdx) for more details.

## Dependencies System

When building services that users might want to swap out, register them in `Spree::Dependencies`:

```ruby
# In the dependency configuration
Spree::Dependencies.cart_add_item_service = 'Spree::Cart::AddItem'
```

This allows users to replace services without modifying core code.

## Admin Development

When adding new resources to the admin, you need to register tables and navigation.

### Admin Tables

For rendering records lists in Admin always use [Admin Tables](docs/developer/admin/tables.mdx)
Register new tables in `admin/config/initializers/spree_admin_tables.rb`:

```ruby
Rails.application.config.after_initialize do
  # Register the table
  Spree.admin.tables.register(:gift_cards, model_class: Spree::GiftCard, search_param: :multi_search)

  # Add columns
  Spree.admin.tables.gift_cards.add :code,
                                    label: :code,
                                    type: :string,
                                    sortable: true,
                                    filterable: true,
                                    default: true,
                                    position: 10

  Spree.admin.tables.gift_cards.add :balance,
                                    label: :balance,
                                    type: :currency,
                                    sortable: true,
                                    default: true,
                                    position: 20

  Spree.admin.tables.gift_cards.add :status,
                                    label: :status,
                                    type: :custom,
                                    filter_type: :status,
                                    sortable: true,
                                    filterable: true,
                                    default: true,
                                    position: 30,
                                    partial: 'spree/admin/tables/columns/gift_card_status'
end
```

Column types: `:string`, `:currency`, `:date`, `:datetime`, `:boolean`, `:custom` (requires `partial`)

### Admin Navigation

Register navigation items in `admin/config/initializers/spree_admin_navigation.rb`:

```ruby
Rails.application.config.after_initialize do
  # Sidebar navigation
  sidebar_nav = Spree.admin.navigation.sidebar

  # Simple item
  sidebar_nav.add :reports,
          label: :reports,
          url: :admin_reports_path,
          icon: 'chart-bar',
          position: 60,
          if: -> { can?(:manage, Spree::Report) }

  # Item with submenu
  sidebar_nav.add :products,
          label: :products,
          url: :admin_products_path,
          icon: 'package',
          position: 30,
          if: -> { can?(:manage, Spree::Product) } do |products|

    products.add :price_lists,
                label: :price_lists,
                url: :admin_price_lists_path,
                position: 10,
                if: -> { can?(:manage, Spree::PriceList) }

    products.add :stock,
                label: :stock,
                url: :admin_stock_items_path,
                position: 20,
                if: -> { can?(:manage, Spree::StockItem) }
  end

  # Settings navigation
  settings_nav = Spree.admin.navigation.settings

  settings_nav.add :payment_methods,
          label: :payments,
          url: :admin_payment_methods_path,
          icon: 'credit-card',
          position: 70,
          active: -> { controller_name == 'payment_methods' },
          if: -> { can?(:manage, Spree::PaymentMethod) }

  # Tab navigation (for pages with tabs)
  tax_tabs_nav = Spree.admin.navigation.tax_tabs

  tax_tabs_nav.add :tax_rates,
          label: :tax_rates,
          url: :admin_tax_rates_path,
          position: 10,
          if: -> { can?(:manage, Spree::TaxRate) }
end
```

Navigation options:
- `label` - Translation key or string
- `url` - Route helper symbol or lambda
- `icon` - Tabler icon name (see https://tabler.io/icons)
- `position` - Sort order (lower = higher)
- `if` - Lambda for conditional display
- `active` - Lambda for active state detection
- `badge` - Lambda returning badge text
- `badge_class` - CSS class for badge

## Testing

Always run tests before committing changes. Always run tests after making changes.

### Test Application

To run tests you need to create test app with `bundle exec rake test_app` in every gem directory (eg. admin, api, core, etc.)

This will create a dummy rails application and run migrations. If there's already a dummy app in the gem directory, you can skip this step.

### Test Structure

- Use RSpec for testing and Factory Bot for creating test data
- As much as you can use build vs create for Factories to speed up tests
- Be very pragmatic, and don't over-engineer tests, don't repeat same tests in multiple places, tests must be fast
- Create test app with `bundle exec rake test_app` in every gem directory (eg. admin, api, core, etc.)
- Place specs in appropriate directories matching app structure
- For controller specs always add `render_views` to the test
- For controller spec authentication use `stub_authorization!`
- Don't create test scenarios for standard rails validation, only for custom validations
- For time-based testing / operations use `Timecop` gem
- Be pragmatic, and don't over-engineer tests, don't repeat same tests in multiple places

```ruby
# ✅ Proper spec structure
require 'spec_helper'

RSpec.describe Spree::Product, type: :model do
  let(:product) { create(:product) }
  
  describe '#custom_method' do
    it 'returns expected result' do
      expect(product.custom_method).to eq('EXPECTED')
    end
  end
end
```

### Factory Usage

- Use `create` for persisted objects in tests
- Use `build` for non-persisted objects, recommended as it's much faster than `create`
- Add new factories in `lib/spree/testing_support/factories/`

```ruby
# ✅ Proper factory usage
let(:product) { create(:product, name: 'Test Product') }
let(:variant) { build(:variant, product: product) }
```

## Security

### Authentication & Authorization

- Follow Rails Security Guide principles
- Define permissions in Permission Sets, see [Permissions](/docs/developer/customization/permissions.mdx) for more details
- Implement proper authorization checks with CanCanCan
- Validate all user inputs
- In Admin controllers inheriting from `Spree::Admin::ResourceController` will automatically secure all actions
- Authentication is handled by app developers, by default we provide Devise installer, always use `Spree.user_class` to access the user model for Customers and `Spree.admin_user_class` to access the user model for Admins

### Parameter Security

- Never permit mass assignment without validation
- Spree uses `Spree::PermittedAttributes` to define allowed parameters for each resource globally
- Use allowlists, not blocklists for parameters
- Sanitize user inputs appropriately

## Database & Migrations

### Migration Patterns

- Follow Rails migration conventions
- Use proper indexing for performance
- Do not include foreign key constraints
- Use descriptive migration names with timestamps
- Try to limit number of migrations to 1 per feature
- Avoid using default values in migrations
- Always add `null: false` to required columns
- Always try to combine multiple migrations into one if possible when developing a new feature
- If new feature require transformation of existing data please add a rake task to do the transformation, never do it in a migration
- Add unique indexes to columns that are used for uniqueness validation
- By default add `deleted_at` column to all tables that have soft delete functionality (we use `paranoia` gem)
- For migrations please use 7.2 as the target version as we still support Rails 7.2

```ruby
# ✅ Proper migration structure
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

### Database Design

- Use appropriate column types and constraints
- Implement proper foreign key relationships
- Consider indexing for query performance
- Use polymorphic associations when appropriate

## Frontend Development

### Admin Interface

- Use Spree's admin styling conventions
- Use as much as possible Turbo Rails features (Hotwire)
- Use Stimulus controllers for JavaScript interactions
- Please use [Admin Components](docs/developer/admin/components.mdx) for elements such as dialogs, drawers, dropdowns, and more.
- Please use [Spree::Admin::FormBuilder](docs/developer/admin/form-builder.mdx) methods for form fields
- For rendering record lists please use [Admin Tables](docs/developer/admin/tables.mdx)

For create new resource form:

```erb
<!-- ✅ Proper admin form structure -->
<%= render 'spree/admin/shared/new_resource' %>
```

For edit resource form:

```erb
<%= render 'spree/admin/shared/edit_resource' %>
```

And the re-usable form partial should be in `app/views/spree/admin/products/_form.html.erb`, eg.

```erb
<div class="card mb-6">
  <div class="card-header">
    <h5 class="card-title">
      <%= Spree.t(:general_settings) %>
    </h5>
  </div>

  <div class="card-body">
    <%= f.spree_text_field :name %>
    <%= f.spree_rich_text_area :description %>
    <%= f.spree_check_box :active %>
  </div>
</div>
```

## Performance & Best Practices

### Query Optimization

- We're using ar_lazy_preload gem to avoid N+1 queries, however please use includes/preload to avoid N+1 queries as much as possible
- Implement proper database indexing
- Use scopes for reusable query logic
- Consider caching for expensive operations

```ruby
# ✅ Optimized queries
products = Spree::Product.includes(:variants, :thumbnail)
                         .where(available_on: ..Time.current)
                         .order(:name)
```

### Caching

- Use Rails caching mechanisms appropriately (via `Rails.cache`)
- Cache expensive calculations and queries, however caching one query is not recommended
- Implement cache invalidation strategies, use Rails `cache_key_with_version` when constructing custom cache keys
- Consider fragment caching for views

### Code Quality

- Follow Ruby style guidelines
- Keep methods small and focused
- Use meaningful variable and method names
- Write self-documenting code with appropriate comments
- Avoid deep nesting and complex conditionals
- Avoid business logic in controllers, move that to models and use concerns
- Use services only when necessary, we should as much as we possible use standard Rails models and Concerns
- Use concerns for reusable code

## Documentation & Comments

### Code Documentation

- Document complex business logic
- Explain non-obvious code patterns
- Use YARD documentation format for public APIs
- Keep comments up-to-date with code changes

## Error Handling

### Exception Management

- Use Rails error reporter - https://guides.rubyonrails.org/error_reporting.html
- Use appropriate exception classes
- Provide meaningful error messages
- Implement proper error recovery where possible

```ruby
# ✅ Proper error handling
def process_payment
  payment_service.call
rescue Spree::PaymentProcessingError => e
  Rails.error.report e
  flash[:error] = I18n.t('spree.payment_processing_failed')
  false
end
```

This document should be updated as Spree evolves and new patterns emerge. Always refer to the official Spree documentation for the most current practices and guidelines.

## Routes

- Always use `spree.` routes engine when using routes in views and controllers

## Internationalization

- Use Rails 18n for internationalization
- Use `Spree.t` for translations
- Please keep admin translations in `admin/config/locales/en.yml`
- Please keep storefront translations in `storefront/config/locales/en.yml`
- Please keep all other translations in `config/locales/en.yml`
- Please do not repeat translations in multiple files, use `Spree.t` instead
- Please try to use existing translations as much as possible
