# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Wishlists API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:wishlist) { create(:wishlist, user: user, store: store, name: 'My Wishlist') }
  let!(:product) { create(:product, stores: [store]) }
  let!(:variant) { product.master }
  let!(:wished_item) { create(:wished_item, wishlist: wishlist, variant: variant) }

  path '/api/v3/store/wishlists' do
    get 'List wishlists' do
      tags 'Wishlists'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all wishlists for the authenticated customer'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response '200', 'wishlists found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreWishlist' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].size).to be >= 1
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a wishlist' do
      tags 'Wishlists'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Creates a new wishlist for the customer'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          wishlist: {
            type: :object,
            properties: {
              name: { type: :string },
              is_private: { type: :boolean },
              is_default: { type: :boolean }
            },
            required: %w[name]
          }
        }
      }

      response '201', 'wishlist created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { wishlist: { name: 'Birthday Ideas', is_private: true } } }

        schema '$ref' => '#/components/schemas/StoreWishlist'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Birthday Ideas')
          expect(data['is_private']).to be true
        end
      end

      response '422', 'validation error' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { wishlist: { name: '' } } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/wishlists/{id}' do
    get 'Get a wishlist' do
      tags 'Wishlists'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Include wished_items'

      response '200', 'wishlist found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { wishlist.to_param }

        schema '$ref' => '#/components/schemas/StoreWishlist'

        run_test!
      end

      response '404', 'wishlist not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a wishlist' do
      tags 'Wishlists'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          wishlist: {
            type: :object,
            properties: {
              name: { type: :string },
              is_private: { type: :boolean },
              is_default: { type: :boolean }
            }
          }
        }
      }

      response '200', 'wishlist updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { wishlist.to_param }
        let(:body) { { wishlist: { name: 'Updated Name' } } }

        schema '$ref' => '#/components/schemas/StoreWishlist'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Updated Name')
        end
      end
    end

    delete 'Delete a wishlist' do
      tags 'Wishlists'
      security [api_key: [], bearer_auth: []]

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'wishlist deleted' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { wishlist.to_param }

        run_test!
      end
    end
  end

  path '/api/v3/store/wishlists/{wishlist_id}/items' do
    post 'Add item to wishlist' do
      tags 'Wishlists'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a variant to the wishlist'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :wishlist_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          variant_id: { type: :string },
          quantity: { type: :integer }
        },
        required: %w[variant_id]
      }

      response '201', 'item added' do
        let(:new_product) { create(:product, stores: [store]) }
        let(:new_variant) { new_product.master }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:wishlist_id) { wishlist.to_param }
        let(:body) { { wished_item: { variant_id: new_variant.id.to_s, quantity: 1 } } }

        schema '$ref' => '#/components/schemas/StoreWishedItem'

        run_test!
      end
    end
  end

  path '/api/v3/store/wishlists/{wishlist_id}/items/{id}' do
    delete 'Remove item from wishlist' do
      tags 'Wishlists'
      security [api_key: [], bearer_auth: []]

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :wishlist_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '204', 'item removed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:wishlist_id) { wishlist.to_param }
        let(:id) { wished_item.to_param }

        run_test!
      end

      response '404', 'item not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:wishlist_id) { wishlist.to_param }
        let(:id) { 'non-existent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
