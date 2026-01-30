# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Orders API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }
  let!(:order) { create(:order_with_line_items, store: store, user: user) }

  path '/api/v3/store/orders' do
    get 'List orders' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of orders for the authenticated customer'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: 'q[state_eq]', in: :query, type: :string, required: false,
                description: 'Filter by order state'
      parameter name: 'q[completed_at_gte]', in: :query, type: :string, required: false,
                description: 'Filter by completion date (after)'

      response '200', 'orders found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StoreOrder' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end

      response '401', 'unauthorized - authentication required' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a cart' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Creates a new order (shopping cart). Can be created by guests or authenticated customers.
        Returns an `order_token` that must be used for guest access to the order.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer JWT token (optional - for authenticated customers)'

      response '201', 'cart created (guest)' do
        let(:'x-spree-api-key') { api_key.token }

        schema type: :object,
               allOf: [
                 { '$ref' => '#/components/schemas/StoreOrder' },
                 {
                   type: :object,
                   properties: {
                     order_token: { type: :string, description: 'Token for guest access to this order' }
                   }
                 }
               ]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to be_present
          expect(data['state']).to eq('cart')
          expect(data['order_token']).to be_present
        end
      end

      response '201', 'cart created (authenticated)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               allOf: [
                 { '$ref' => '#/components/schemas/StoreOrder' },
                 { type: :object, properties: { order_token: { type: :string } } }
               ]

        run_test!
      end

      response '401', 'unauthorized - invalid API key' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{id}' do
    get 'Get an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single order by ID or number. Guests must provide order_token.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID (prefixed) or order number'
      parameter name: :order_token, in: :query, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :includes, in: :query, type: :string, required: false,
                description: 'Include associations (line_items, shipments, payments)'

      response '200', 'order found (authenticated)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { order.to_param }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(order.number)
        end
      end

      response '200', 'order found (guest with token)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { order.to_param }
        let(:order_token) { order.token }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'R999999999' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '403', 'forbidden - order belongs to another user' do
        let(:other_user) { create(:user) }
        let(:other_order) { create(:order, store: store, user: other_user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { other_order.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates order attributes like email, special instructions, or addresses'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          order: {
            type: :object,
            properties: {
              email: { type: :string, format: 'email' },
              special_instructions: { type: :string },
              bill_address_attributes: { '$ref' => '#/components/schemas/StoreAddress' },
              ship_address_attributes: { '$ref' => '#/components/schemas/StoreAddress' }
            }
          }
        }
      }

      response '200', 'order updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { order.to_param }
        let(:body) { { order: { special_instructions: 'Leave at door' } } }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['special_instructions']).to eq('Leave at door')
        end
      end

      response '403', 'cannot update completed order' do
        let(:completed_order) { create(:completed_order_with_totals, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { completed_order.to_param }
        let(:body) { { order: { special_instructions: 'Test' } } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{id}/next' do
    patch 'Advance to next checkout step' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Advances the order to the next state in the checkout flow'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false

      response '200', 'order advanced' do
        let(:advanceable_order) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { advanceable_order.to_param }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end

      response '422', 'cannot advance - validation errors' do
        let(:invalid_order) { create(:order, store: store, user: user, state: 'address', bill_address: nil, ship_address: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { invalid_order.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{id}/advance' do
    patch 'Advance through checkout' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Advances the order through all possible checkout states'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false

      response '200', 'order advanced' do
        let(:advanceable_order) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { advanceable_order.to_param }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{id}/complete' do
    patch 'Complete the order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Completes the order (finalizes the purchase)'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false

      response '200', 'order completed' do
        let(:completable_order) do
          order = create(:order_with_line_items, store: store, user: user)
          # Advance through checkout - order_with_line_items has addresses set
          Spree.checkout_advance_service.call(order: order)
          # Add payment to reach confirm state
          payment_method = create(:check_payment_method, stores: [store])
          create(:payment, order: order, amount: order.total, payment_method: payment_method, state: 'checkout')
          order.reload
        end
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { completable_order.to_param }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end

      response '422', 'cannot complete' do
        let(:incomplete_order) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { incomplete_order.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/store_credits' do
    post 'Add store credit' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Applies store credit to the order'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :number, description: 'Amount to apply (optional - defaults to max available)' }
        }
      }

      response '200', 'store credit applied' do
        let(:store_credit_payment_method) { create(:store_credit_payment_method, stores: [store]) }
        let(:store_credit) { create(:store_credit, user: user, store: store, amount: 50) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:body) { { amount: 10 } }

        before do
          store_credit_payment_method
          store_credit
        end

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end

      response '422', 'no store credit available' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Remove store credit' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes store credit from the order'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false

      response '200', 'store credit removed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end
    end
  end
end
