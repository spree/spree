# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  path '/api/v3/store/cart' do
    post 'Create a new cart' do
      tags 'Cart'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Creates a new shopping cart (order). Can be created by guests or authenticated customers.
        Returns a `token` that must be used for guest access to the order.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer JWT token (optional - for authenticated customers)'

      response '201', 'cart created (guest)' do
        let(:'x-spree-api-key') { api_key.token }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to be_present
          expect(data['state']).to eq('cart')
          expect(data['token']).to be_present
        end
      end

      response '201', 'cart created (authenticated)' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test!
      end

      response '401', 'unauthorized - invalid API key' do
        let(:'x-spree-api-key') { 'invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    get 'Get current cart' do
      tags 'Cart'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the current shopping cart (incomplete order).
        Authenticate via JWT token for logged-in users or via order_token parameter for guests.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer JWT token for authenticated customers'
      parameter name: :order_token, in: :query, type: :string, required: false,
                description: 'Order token for guest checkout'

      response '200', 'cart found (guest)' do
        let(:cart) { create(:order_with_line_items, store: store) }
        let(:'x-spree-api-key') { api_key.token }
        let(:order_token) { cart.token }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(cart.number)
          expect(data['token']).to eq(cart.token)
          expect(data['line_items']).to be_present
        end
      end

      response '200', 'cart found (authenticated)' do
        let!(:cart) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/StoreOrder'

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

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true,
                description: 'Bearer JWT token (required)'
      parameter name: 'x-spree-order-token', in: :header, type: :string, required: false,
                description: 'Order token (can also be passed as query param)'
      parameter name: :order_token, in: :query, type: :string, required: false,
                description: 'Order token (alternative to header)'

      response '200', 'cart associated successfully' do
        let(:guest_cart) { create(:order_with_line_items, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_token) { guest_cart.token }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(guest_cart.number)
          expect(guest_cart.reload.user).to eq(user)
        end
      end

      response '401', 'unauthorized - JWT required' do
        let(:guest_cart) { create(:order_with_line_items, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:order_token) { guest_cart.token }

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
        let(:order_token) { other_cart.token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('order_not_found')
        end
      end

      response '404', 'cart not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_token) { 'invalid_token' }

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
        let(:order_token) { completed_order.token }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['code']).to eq('order_not_found')
        end
      end
    end
  end
end
