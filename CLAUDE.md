# Claude Code Rules for Spree Commerce Development

## General Development Guidelines

### Framework & Architecture

- Spree is built on Ruby on Rails and follows MVC architecture
- All Spree code must be namespaced under `Spree::` module
- Spree is distributed as Rails engines with separate gems (core, admin, api, storefront, emails, etc.)
- Follow Rails conventions and the Rails Security Guide
- Prefer Rails idioms and standard patterns over custom solutions

### Code Organization

- Place all models in `app/models/spree/` directory
- Place all controllers in `app/controllers/spree/` directory  
- Place all views in `app/views/spree/` directory
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
- Views: `app/views/spree/admin/products/`
- Decorators: `app/models/spree/product_decorator.rb`

## Model Development

### Model Patterns

- Use ActiveRecord associations appropriately, always pass `class_name` and `dependent` options
- Implement concerns for shared functionality
- Use scopes for reusable query patterns
- Include `Spree::Metafields` concern for models that need metadata support
- Don't use enums, use string columns instead
- For models that require state machine, please use https://github.com/state-machines/state_machines-activerecord gem, default column should be `status`, legacy models use `state`

```ruby
# ✅ Good model structure
class Spree::Product < ApplicationRecord
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
- API controllers inherit from `Spree::Api::V2::BaseController`
- Storefront controllers inherit from `Spree::StoreController`

### Parameter Handling

- Always use strong parameters
- Always use `Spree::PermittedAttributes` to define allowed parameters for each resource

```ruby
# ✅ Proper parameter handling
def permitted_product_params
  params.require(:product).permit(Spree::PermittedAttributes.product_attributes)
end
```

## Customization & Extensions

### Decorators (Use Sparingly)

- Decorators should be a last resort - they make upgrades difficult
- Use `Module.prepend` pattern for decorators
- Name decorator files with `_decorator.rb` suffix

```ruby
# ✅ Proper decorator structure
module Spree
  module ProductDecorator
    def custom_method
      # Custom functionality
      name.upcase
    end
    
    def existing_method
      # Extend existing method
      result = super
      # Additional logic
      result
    end
  end

  Product.prepend(ProductDecorator)
end
```

## Testing

### Test Application

To run tests you need to create test app with `bundle exec rake test_app` in every gem directory (eg. admin, api, core, etc.)

This will create a dummy rails application and run migrations. If there's already a dummy app in the gem directory, you can skip this step.

### Test Structure

- Use RSpec for testing
- Create test app with `bundle exec rake test_app` in every gem directory (eg. admin, api, core, etc.)
- Place specs in appropriate directories matching app structure
- Use Spree's factory bot definitions
- For controller specs always add `render_views` to the test
- For controller spec authentication use `stub_authorization!`
- Don't create test scenarios for standard rails validation, only for custom validations

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
- Use strong parameters consistently
- Implement proper authorization checks
- Validate all user inputs
- In Admin controllers inheriting from `Spree::Admin::ResourceController` will automatically secure all actions
- We use CanCanCan for authorization
- Authentication is handled by app developers, by default we provide Devise installer

### Parameter Security

- Never permit mass assignment without validation
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
- Add unique indexes to columns that are used for uniqueness validation
- By default add `deleted_at` column to all tables that have soft delete functionality (we use `paranoia` gem)

```ruby
# ✅ Proper migration structure
class CreateSpreeMetafields < ActiveRecord::Migration[8.0]
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

### Storefront Development

- Use Tailwind CSS for styling
- Follow responsive design principles
- Implement proper SEO meta tags
- Ensure accessibility compliance

### Admin Interface

- Use Spree's admin styling conventions
- Use as much as possible Turbo Rails features (Hotwire)
- Re-usable components should be helpers
- Please use `Spree::Admin::FormBuilder` methods for form fields
- Follow UX patterns established in core admin
- Use Stimulus controllers for JavaScript interactions

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
<div class="card mb-4">
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

- Use includes/preload to avoid N+1 queries
- Implement proper database indexing
- Use scopes for reusable query logic
- Consider caching for expensive operations

```ruby
# ✅ Optimized queries
products = Spree::Product.includes(:variants, :images)
                         .where(available_on: ..Time.current)
                         .order(:name)
```

### Caching

- Use Rails caching mechanisms appropriately
- Cache expensive calculations and queries
- Implement cache invalidation strategies
- Consider fragment caching for views

### Code Quality

- Follow Ruby style guidelines
- Keep methods small and focused
- Use meaningful variable and method names
- Write self-documenting code with appropriate comments
- Avoid deep nesting and complex conditionals

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
