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

      sdk_example <<~JS
        const wishlists = await client.store.wishlists.list({}, {
          bearerToken: '<token>',
        })
      JS

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

      sdk_example <<~JS
        const wishlist = await client.store.wishlists.create({
          name: 'Birthday Ideas',
          is_private: true,
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Birthday Ideas' },
          is_private: { type: :boolean, example: true },
          is_default: { type: :boolean, example: false }
        },
        required: %w[name]
      }

      response '201', 'wishlist created' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { name: 'Birthday Ideas', is_private: true } }

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
        let(:body) { { name: '' } }

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

      sdk_example <<~JS
        const wishlist = await client.store.wishlists.get('wl_abc123', {
          includes: 'wished_items',
        }, {
          bearerToken: '<token>',
        })
      JS

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

      sdk_example <<~JS
        const wishlist = await client.store.wishlists.update('wl_abc123', {
          name: 'Updated Name',
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Updated Name' },
          is_private: { type: :boolean, example: true },
          is_default: { type: :boolean, example: false }
        }
      }

      response '200', 'wishlist updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { wishlist.to_param }
        let(:body) { { name: 'Updated Name' } }

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

      sdk_example <<~JS
        await client.store.wishlists.delete('wl_abc123', {
          bearerToken: '<token>',
        })
      JS

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

      sdk_example <<~JS
        const item = await client.store.wishlists.items.create('wl_abc123', {
          variant_id: 'variant_abc123',
          quantity: 1,
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :wishlist_id, in: :path, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          variant_id: { type: :string, example: 'variant_abc123' },
          quantity: { type: :integer, example: 1 }
        },
        required: %w[variant_id]
      }

      response '201', 'item added' do
        let(:new_product) { create(:product, stores: [store]) }
        let(:new_variant) { new_product.master }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:wishlist_id) { wishlist.to_param }
        let(:body) { { variant_id: new_variant.prefixed_id, quantity: 1 } }

        schema '$ref' => '#/components/schemas/StoreWishedItem'

        run_test!
      end
    end
  end

  path '/api/v3/store/wishlists/{wishlist_id}/items/{id}' do
    delete 'Remove item from wishlist' do
      tags 'Wishlists'
      security [api_key: [], bearer_auth: []]

      sdk_example <<~JS
        await client.store.wishlists.items.delete('wl_abc123', 'wi_abc123', {
          bearerToken: '<token>',
        })
      JS

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
