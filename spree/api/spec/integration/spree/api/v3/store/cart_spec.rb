# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/cart' do
    post 'Create a new cart' do
      tags 'Cart'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Creates a new shopping cart. Can be created by guests or authenticated customers.
        Returns a `token` that must be used for guest access to the cart.
      DESC

      sdk_example <<~JS
        // Create an empty cart
        const cart = await client.cart.create()

        // Create a cart with line items
        const cartWithItems = await client.cart.create({
          line_items: [
            { variant_id: 'variant_abc123', quantity: 2 },
          ],
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer JWT token (optional - for authenticated customers)'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          metadata: { type: :object, description: 'Write-only key-value metadata (Stripe-style). Not returned in responses.' },
          line_items: {
            type: :array,
            description: 'Line items to add to the cart on creation',
            items: {
              type: :object,
              properties: {
                variant_id: { type: :string, example: 'variant_abc123', description: 'Prefixed variant ID' },
                quantity: { type: :integer, example: 2, description: 'Quantity (defaults to 1)' },
                metadata: { type: :object, additionalProperties: true, description: 'Arbitrary key-value metadata' }
              },
              required: %w[variant_id]
            }
          }
        }
      }
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency. Duplicate requests with the same key return the cached response.'

      response '201', 'cart created (guest)' do
        let(:'x-spree-api-key') { api_key.token }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to be_present
          expect(data['state']).to eq('cart')
          expect(data['token']).to be_present
        end
      end

      response '201', 'cart created (authenticated)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/Cart'

        run_test!
      end

      response '201', 'cart created with line items' do
        let(:product) { create(:product, stores: [store]) }
        let(:variant) { create(:variant, product: product) }

        before { variant.stock_items.first.update!(count_on_hand: 10) }

        let(:'x-spree-api-key') { api_key.token }
        let(:body) do
          {
            line_items: [
              { variant_id: variant.prefixed_id, quantity: 3 }
            ]
          }
        end

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['line_items'].size).to eq(1)
          expect(data['line_items'].first['quantity']).to eq(3)
          expect(data['line_items'].first['variant_id']).to eq(variant.prefixed_id)
        end
      end

      response '201', 'cart created with metadata' do
        let(:'x-spree-api-key') { api_key.token }
        let(:body) { { metadata: { 'source' => 'mobile_app', 'campaign' => 'summer_sale' } } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to be_present
          order = Spree::Order.find_by!(number: data['number'])
          expect(order.metadata).to eq({ 'source' => 'mobile_app', 'campaign' => 'summer_sale' })
        end
      end

      response '401', 'unauthorized - invalid API key' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '400', 'idempotency key too long' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Idempotency-Key') { 'a' * 256 }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('invalid_request')
        end
      end

      response '422', 'idempotency key reused with different parameters' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Idempotency-Key') { 'test-idempotency-key' }

        around do |example|
          original_cache = Rails.cache
          Rails.cache = ActiveSupport::Cache::MemoryStore.new
          example.run
        ensure
          Rails.cache = original_cache
        end

        before do
          post '/api/v3/store/cart',
               headers: { 'x-spree-api-key' => api_key.token, 'Idempotency-Key' => 'test-idempotency-key' },
               as: :json
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('idempotency_key_reused')
        end
      end
    end

    get 'Get current cart' do
      tags 'Cart'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the current shopping cart (incomplete order).
        Authenticate via JWT token for logged-in users or via x-spree-token header for guests.
      DESC

      sdk_example <<~JS
        // Authenticated customer
        const cart = await client.cart.get({
          bearerToken: '<token>',
        })

        // Guest with order token
        const guestCart = await client.cart.get({
          orderToken: 'ORDER_TOKEN',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer JWT token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest checkout'

      response '200', 'cart found (guest)' do
        let(:cart) { create(:order_with_line_items, store: store) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'x-spree-token') { cart.token }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(cart.number)
          expect(data['token']).to eq(cart.token)
          expect(data['line_items']).to be_present
        end
      end

      response '200', 'cart found (authenticated)' do
        let!(:cart) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(cart.number)
        end
      end

      response '404', 'no cart found' do
        let(:'x-spree-api-key') { api_key.token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('order_not_found')
        end
      end
    end

    delete 'Delete current cart' do
      tags 'Cart'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes/abandons the current shopping cart.'

      sdk_example <<~JS
        await client.cart.delete({
          orderToken: 'ORDER_TOKEN',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false

      response '204', 'cart deleted' do
        let!(:cart) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test!
      end
    end
  end

  path '/api/v3/store/cart/associate' do
    patch 'Associate guest cart with authenticated user' do
      tags 'Cart'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Associates a guest cart with the currently authenticated user.
        Requires both JWT authentication and an order token.
        The order must not be completed and must not belong to another user.
      DESC

      sdk_example <<~JS
        const cart = await client.cart.associate({
          bearerToken: '<token>',
          orderToken: 'GUEST_ORDER_TOKEN',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer JWT token (required)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: true,
                description: 'Order token for identifying the guest cart'

      response '200', 'cart associated successfully' do
        let(:guest_cart) { create(:order_with_line_items, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:'x-spree-token') { guest_cart.token }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(guest_cart.number)
          expect(guest_cart.reload.user).to eq(user)
        end
      end

      response '401', 'unauthorized - JWT required' do
        let(:guest_cart) { create(:order_with_line_items, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:'x-spree-token') { guest_cart.token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('authentication_required')
        end
      end

      response '404', 'cart belongs to another user' do
        let(:other_user) { create(:user) }
        let(:other_cart) { create(:order_with_line_items, store: store, user: other_user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:'x-spree-token') { other_cart.token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('order_not_found')
        end
      end

      response '404', 'cart not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:'x-spree-token') { 'invalid_token' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('order_not_found')
        end
      end

      response '404', 'cart already completed' do
        let(:completed_order) { create(:completed_order_with_totals, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:'x-spree-token') { completed_order.token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('order_not_found')
        end
      end
    end
  end
end
