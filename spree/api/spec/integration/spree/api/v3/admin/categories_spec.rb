# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Categories API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  # A top-level category — parentless, store-owned, no taxonomy.
  let!(:category) { Spree::Category.create!(name: 'Clothing', store: store) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/categories' do
    get 'List categories' do
      tags 'Categories'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of the store\'s categories (manual hierarchical taxons; rule-based collections are excluded).'
      admin_scope :read, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., children, parent, ancestors).'

      response '200', 'categories found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('Category')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end

    post 'Create a category' do
      tags 'Categories'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a category. Nests under the parent when parent_id is given, otherwise creates a top-level category.'
      admin_scope :write, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Shirts' },
          parent_id: { type: :string, example: 'ctg_abc123', description: 'Prefixed ID of the parent category' },
          description: { type: :string },
          permalink: { type: :string },
          meta_title: { type: :string },
          meta_description: { type: :string },
          meta_keywords: { type: :string },
          hide_from_nav: { type: :boolean, example: false }
        },
        required: %w[name]
      }

      response '201', 'category created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: 'Shirts', parent_id: category.prefixed_id } }

        schema '$ref' => '#/components/schemas/Category'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Shirts')
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/categories/{id}' do
    get 'Get a category' do
      tags 'Categories'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single category by ID.'
      admin_scope :read, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Category ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., children, parent, ancestors).'

      response '200', 'category found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { category.prefixed_id }

        schema '$ref' => '#/components/schemas/Category'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(category.prefixed_id)
        end
      end

      response '404', 'category not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'ctg_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a category' do
      tags 'Categories'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a category.'
      admin_scope :write, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Category ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Apparel' },
          parent_id: { type: :string, description: 'Prefixed ID of the parent category' },
          description: { type: :string },
          permalink: { type: :string },
          meta_title: { type: :string },
          meta_description: { type: :string },
          meta_keywords: { type: :string },
          hide_from_nav: { type: :boolean }
        }
      }

      response '200', 'category updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { category.prefixed_id }
        let(:body) { { name: 'Apparel' } }

        schema '$ref' => '#/components/schemas/Category'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Apparel')
        end
      end
    end

    delete 'Delete a category' do
      tags 'Categories'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a category and its descendants.'
      admin_scope :write, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Category ID'

      response '204', 'category deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { category.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/categories/{id}/reposition' do
    patch 'Reposition a category' do
      tags 'Categories'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Moves a category to a new parent and/or index within the tree.'
      admin_scope :write, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Category ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          new_parent_id: { type: :string, description: 'Prefixed ID of the new parent (omit for top level)' },
          new_position: { type: :integer, description: '0-based index among the new parent\'s children' }
        },
        required: %w[new_position]
      }

      response '200', 'category repositioned' do
        let!(:other) { Spree::Category.create!(name: 'Footwear', store: store) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { other.prefixed_id }
        let(:body) { { new_parent_id: category.prefixed_id, new_position: 0 } }

        schema '$ref' => '#/components/schemas/Category'

        run_test!
      end
    end
  end

  path '/api/v3/admin/categories/{category_id}/products' do
    get 'List category products' do
      tags 'Categories'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Products classified under the category, ordered by their classification position.'
      admin_scope :read, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :category_id, in: :path, type: :string, required: true, description: 'Category ID'

      response '200', 'products found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:category_id) { category.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Product')

        run_test!
      end
    end

    post 'Add a product to a category' do
      tags 'Categories'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Classifies a product under the category (appended to the end).'
      admin_scope :write, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :category_id, in: :path, type: :string, required: true, description: 'Category ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { product_id: { type: :string, example: 'prod_abc123' } },
        required: %w[product_id]
      }

      response '201', 'product added' do
        let!(:product) { create(:product, store: store) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:category_id) { category.prefixed_id }
        let(:body) { { product_id: product.prefixed_id } }

        schema '$ref' => '#/components/schemas/Product'

        run_test!
      end
    end
  end

  path '/api/v3/admin/categories/{category_id}/products/{id}' do
    delete 'Remove a product from a category' do
      tags 'Categories'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes a product from the category\'s manual classification.'
      admin_scope :write, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :category_id, in: :path, type: :string, required: true, description: 'Category ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product ID'

      response '204', 'product removed' do
        let!(:product) { create(:product, stores: [store]) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:category_id) { category.prefixed_id }
        let(:id) { product.prefixed_id }

        before { Spree::ProductCategory.create!(taxon: category, product: product, position: 1) }

        run_test!
      end
    end
  end

  path '/api/v3/admin/categories/{category_id}/products/{id}/reposition' do
    patch 'Reposition a category product' do
      tags 'Categories'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Moves a product to a new index among the category\'s products.'
      admin_scope :write, :categories

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :category_id, in: :path, type: :string, required: true, description: 'Category ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { new_position: { type: :integer, description: '0-based index among the category\'s products' } },
        required: %w[new_position]
      }

      response '204', 'product repositioned' do
        let!(:product) { create(:product, store: store) }
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:category_id) { category.prefixed_id }
        let(:id) { product.prefixed_id }
        let(:body) { { new_position: 0 } }

        before { Spree::ProductCategory.create!(taxon: category, product: product, position: 1) }

        run_test!
      end
    end
  end
end
