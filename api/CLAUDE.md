# Claude Code Rules for Spree API Development

## API v3 Architecture

### Serializers

API v3 uses Alba serializers following Medusa's pattern with separate Store and Admin types:

**Directory Structure:**
- `app/serializers/spree/api/v3/` - Store serializers (customer-facing)
- `app/serializers/spree/api/v3/admin/` - Admin serializers (extends store serializers)

**Creating a Store Serializer:**

```ruby
module Spree
  module Api
    module V3
      class ProductSerializer < BaseSerializer
        typelize_from Spree::Product
        typelize purchasable: :boolean, in_stock: :boolean, price: 'number | null'

        attributes :id, :name, :description, :slug
        attributes available_on: :iso8601, created_at: :iso8601

        attribute :price do |product|
          product.default_variant.price&.to_f
        end

        many :variants,
             resource: Spree.api.variant_serializer,
             if: proc { params[:includes]&.include?('variants') }
      end
    end
  end
end
```

**Creating an Admin Serializer:**

```ruby
module Spree
  module Api
    module V3
      module Admin
        class ProductSerializer < V3::ProductSerializer
          typelize_from Spree::Product
          typelize cost_price: 'number | null',
                   private_metadata: 'Record<string, unknown> | null'

          attributes :status, :cost_price, :private_metadata

          # Override to use admin variant serializer
          many :variants,
               resource: Spree::Api::V3::Admin::VariantSerializer,
               if: proc { params[:includes]&.include?('variants') }
        end
      end
    end
  end
end
```

### Typelizer DSL

- `typelize_from Model` - Connect serializer to ActiveRecord model for automatic type inference
- `typelize attr: :type` - Define types for computed/delegated attributes not on the model
- Type formats: `:string`, `:boolean`, `:number`, `'string | null'`, `'string[]'`, `'Record<string, unknown>'`

### TypeScript Type Generation

Types are generated to `sdk/src/types/generated/`:

```bash
# Generate types
bundle exec rake typelizer:generate
```

Naming convention:
- Store serializers -> `Store{Name}` (e.g., `StoreProduct`)
- Admin serializers -> `Admin{Name}` (e.g., `AdminProduct`)

### Controllers

**Store API Controllers:**

```ruby
module Spree
  module Api
    module V3
      class ProductsController < BaseController
        def index
          products = current_store.products.available
          render json: serialize(products)
        end

        def show
          product = current_store.products.find_by!(slug: params[:id])
          render json: serialize(product)
        end

        private

        def serialize(resource, options = {})
          serializer_class.new(resource, serializer_params.merge(options)).serialize
        end

        def serializer_class
          Spree.api.product_serializer.constantize
        end

        def serializer_params
          {
            params: {
              store: current_store,
              currency: current_currency,
              includes: include_params
            }
          }
        end
      end
    end
  end
end
```

**Admin API Controllers:**

```ruby
module Spree
  module Api
    module V3
      module Admin
        class ProductsController < AdminController
          def index
            products = scope.ransack(params[:q]).result
            render json: serialize(products)
          end

          private

          def scope
            Spree::Product.accessible_by(current_ability)
          end

          def serializer_class
            Spree::Api::V3::Admin::ProductSerializer
          end
        end
      end
    end
  end
end
```

### API Key Authentication

API v3 uses `Spree::ApiKey` for authentication:

- **Publishable keys** (`spree_pk_xxx`) - Store API, rate-limited
- **Secret keys** (`spree_sk_xxx`) - Admin API, full access

```ruby
# In controllers
before_action :authenticate_api_key!

def current_api_key
  @current_api_key ||= Spree::ApiKey.find_by(key: bearer_token)
end

def admin_context?
  current_api_key&.admin?
end
```

### Testing

**Request Specs:**

```ruby
RSpec.describe 'Products API', type: :request do
  let(:store) { create(:store) }
  let(:api_key) { create(:api_key, scope: 'store', store: store) }
  let(:headers) { { 'Authorization' => "Bearer #{api_key.key}" } }

  describe 'GET /api/v3/products' do
    it 'returns products' do
      product = create(:product, stores: [store])

      get '/api/v3/products', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].first['id']).to eq(product.id)
    end
  end
end
```

### OpenAPI Specification

API specs are documented using rswag:

```ruby
# spec/integration/api/v3/products_spec.rb
RSpec.describe 'Products API', type: :request do
  path '/api/v3/products' do
    get 'List products' do
      tags 'Products'
      produces 'application/json'

      response '200', 'products found' do
        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreProduct' } }
               }
        run_test!
      end
    end
  end
end
```

Generate OpenAPI spec:

```bash
bundle exec rake rswag:specs:swaggerize
```

## File Locations

- Controllers: `app/controllers/spree/api/v3/`
- Serializers: `app/serializers/spree/api/v3/`
- Request specs: `spec/requests/spree/api/v3/`
- Integration specs (rswag): `spec/integration/spree/api/v3/`
- Generated types: `sdk/src/types/generated/`
