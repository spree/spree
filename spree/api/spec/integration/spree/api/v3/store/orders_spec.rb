# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Orders API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }
  let!(:order) { create(:order_with_line_items, store: store, user: user) }

  path '/api/v3/store/orders/{id}' do
    get 'Get an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single order by ID or number. Guests must provide order_token.'

      sdk_example <<~JS
        const order = await client.store.orders.get('or_abc123', {
          includes: 'line_items,shipments',
        }, {
          bearerToken: '<token>',
        })
      JS

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
        let(:guest_order) { create(:order_with_line_items, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { guest_order.to_param }
        let(:order_token) { guest_order.token }

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

      response '404', 'not found - order belongs to another user' do
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
      tags 'Checkout'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates order attributes like email, special instructions, or addresses'

      sdk_example <<~JS
        const order = await client.store.orders.update('or_abc123', {
          email: 'customer@example.com',
          special_instructions: 'Leave at door',
          bill_address: {
            firstname: 'John',
            lastname: 'Doe',
            address1: '123 Main St',
            city: 'New York',
            zipcode: '10001',
            country_iso: 'US',
            state_abbr: 'NY',
          },
        }, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true
      parameter name: :order_token, in: :query, type: :string, required: false
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'customer@example.com' },
          locale: { type: :string, example: 'en' },
          special_instructions: { type: :string, example: 'Leave at door' },
          bill_address: {
            type: :object,
            properties: {
              firstname: { type: :string, example: 'John' },
              lastname: { type: :string, example: 'Doe' },
              address1: { type: :string, example: '123 Main St' },
              address2: { type: :string, example: 'Apt 4B' },
              city: { type: :string, example: 'New York' },
              zipcode: { type: :string, example: '10001' },
              phone: { type: :string, example: '+1 555 123 4567' },
              company: { type: :string, example: 'Acme Inc' },
              country_iso: { type: :string, example: 'US' },
              state_abbr: { type: :string, example: 'NY' }
            }
          },
          ship_address: {
            type: :object,
            properties: {
              firstname: { type: :string, example: 'Jane' },
              lastname: { type: :string, example: 'Smith' },
              address1: { type: :string, example: '456 Oak Ave' },
              address2: { type: :string, example: 'Suite 200' },
              city: { type: :string, example: 'Los Angeles' },
              zipcode: { type: :string, example: '90001' },
              phone: { type: :string, example: '+1 555 987 6543' },
              company: { type: :string },
              country_iso: { type: :string, example: 'US' },
              state_abbr: { type: :string, example: 'CA' }
            }
          }
        }
      }

      response '200', 'order updated' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { order.to_param }
        let(:body) { { special_instructions: 'Leave at door' } }

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
        let(:body) { { special_instructions: 'Test' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{id}/next' do
    patch 'Advance to next checkout step' do
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Advances the order to the next state in the checkout flow'

      sdk_example <<~JS
        const order = await client.store.orders.next('or_abc123', {
          bearerToken: '<token>',
        })
      JS

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
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Advances the order through all possible checkout states'

      sdk_example <<~JS
        const order = await client.store.orders.advance('or_abc123', {
          bearerToken: '<token>',
        })
      JS

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
      tags 'Checkout'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Completes the order (finalizes the purchase)'

      sdk_example <<~JS
        const order = await client.store.orders.complete('or_abc123', {
          bearerToken: '<token>',
        })
      JS

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
end
