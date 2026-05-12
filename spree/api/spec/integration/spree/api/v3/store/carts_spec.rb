# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Carts API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }

  path '/api/v3/store/carts' do
    get 'List active carts' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all active (incomplete) carts for the authenticated user.'

      sdk_example 'carts/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number (default: 1)'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of results per page (default: 25, max: 100)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort order. Prefix with - for descending. Values: created_at, -created_at, updated_at, -updated_at'
      parameter name: 'q[created_at_gt]', in: :query, type: :string, required: false,
                description: 'Filter by created after date (ISO 8601)'
      parameter name: 'q[updated_at_gt]', in: :query, type: :string, required: false,
                description: 'Filter by updated after date (ISO 8601)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (items, fulfillments, payments, discounts, billing_address, shipping_address, gift_card, payment_methods). Use "none" to skip associations.'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., total,amount_due,item_count). id is always included.'

      response '200', 'carts listed' do
        let!(:cart1) { create(:order_with_line_items, store: store, user: user) }
        let!(:cart2) { create(:order_with_line_items, store: store, user: user) }
        let!(:completed_order) { create(:completed_order_with_totals, store: store, user: user) }
        let!(:other_user_cart) { create(:order_with_line_items, store: store, user: create(:user)) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          ids = data['data'].map { |c| c['id'] }
          expect(ids).to all(start_with('cart_'))
          expect(ids.size).to eq(2)
          expect(data['meta']['count']).to eq(2)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a new cart' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: []]
      description <<~DESC
        Creates a new shopping cart. Can be created by guests or authenticated customers.
        Returns a `token` that must be used for guest access to the cart.
      DESC

      sdk_example 'carts/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer JWT token (optional - for authenticated customers)'
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          metadata: { type: :object, description: 'Write-only key-value metadata (Stripe-style).' },
          items: {
            type: :array,
            description: 'Items to add to the cart on creation',
            items: {
              type: :object,
              properties: {
                variant_id: { type: :string, example: 'variant_abc123', description: 'Prefixed variant ID' },
                quantity: { type: :integer, example: 2, description: 'Quantity (defaults to 1)' },
                metadata: { type: :object, additionalProperties: true }
              },
              required: %w[variant_id]
            }
          }
        }
      }
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'

      response '201', 'cart created' do
        let(:'x-spree-api-key') { api_key.token }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to be_present
          expect(data['current_step']).to eq('address')
          expect(data['token']).to be_present
        end
      end
    end
  end

  path '/api/v3/store/carts/{id}' do
    get 'Get a cart' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns a shopping cart by prefixed ID.
        Authorize via x-spree-token header (guest) or JWT Bearer token (authenticated user).
      DESC

      sdk_example 'carts/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true, description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (items, fulfillments, payments, discounts, billing_address, shipping_address, gift_card, payment_methods). Use "none" to skip associations.'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., total,amount_due,item_count). id is always included.'

      response '200', 'cart found' do
        let(:cart) { create(:order_with_line_items, store: store) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'x-spree-token') { cart.token }
        let(:id) { cart.prefixed_id }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(cart.number)
          expect(data['warnings']).to eq([])
        end
      end

      response '200', 'cart with out-of-stock item removed (warnings returned)' do
        let(:cart) { create(:order_with_line_items, store: store) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'x-spree-token') { cart.token }
        let(:id) { cart.prefixed_id }

        before do
          cart.products.first.stock_items.update_all(count_on_hand: 0, backorderable: false)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['warnings']).to be_an(Array)
          expect(data['warnings'].length).to eq(1)
          expect(data['warnings'].first['code']).to eq('line_item_removed')
          expect(data['warnings'].first['message']).to be_present
          expect(data['warnings'].first['variant_id']).to be_present
        end
      end

      response '404', 'cart not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { 'cart_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a cart' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates cart info (email, addresses, customer note). When addresses change, the order state is reverted to address to ensure shipments are recalculated.'

      sdk_example 'carts/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: 'email', example: 'customer@example.com' },
          customer_note: { type: :string, example: 'Leave at door' },
          metadata: { type: :object, additionalProperties: true },
          shipping_address_id: { type: :string, description: 'Existing address ID to use as shipping address', example: 'addr_abc123' },
          billing_address_id: { type: :string, description: 'Existing address ID to use as billing address', example: 'addr_def456' },
          billing_address: {
            type: :object,
            properties: {
              first_name: { type: :string }, last_name: { type: :string },
              address1: { type: :string }, address2: { type: :string },
              city: { type: :string }, postal_code: { type: :string },
              phone: { type: :string }, company: { type: :string },
              country_iso: { type: :string }, state_abbr: { type: :string }
            }
          },
          shipping_address: {
            type: :object,
            properties: {
              first_name: { type: :string }, last_name: { type: :string },
              address1: { type: :string }, address2: { type: :string },
              city: { type: :string }, postal_code: { type: :string },
              phone: { type: :string }, company: { type: :string },
              country_iso: { type: :string }, state_abbr: { type: :string }
            }
          }
        }
      }

      response '200', 'cart updated' do
        let!(:order) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { order.prefixed_id }
        let(:body) { { customer_note: 'Leave at door' } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['customer_note']).to eq('Leave at door')
        end
      end
    end

    delete 'Delete a cart' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes/abandons the cart.'

      sdk_example 'carts/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'

      response '204', 'cart deleted' do
        let!(:cart) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { cart.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/store/carts/{id}/associate' do
    patch 'Associate guest cart with authenticated user' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Associates a guest cart with the currently authenticated user.
        Requires JWT authentication. The cart must not belong to another user.
      DESC

      sdk_example 'carts/associate'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'

      response '200', 'cart associated successfully' do
        let(:guest_cart) { create(:order_with_line_items, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { guest_cart.prefixed_id }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(guest_cart.reload.user).to eq(user)
        end
      end

      response '401', 'unauthorized - JWT required' do
        let(:guest_cart) { create(:order_with_line_items, store: store, user: nil) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }
        let(:id) { guest_cart.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/carts/{id}/complete' do
    post 'Complete cart' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Completes the cart and finalizes the purchase. Returns an Order (not Cart).'

      sdk_example 'carts/complete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: :id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'

      response '200', 'cart completed' do
        let(:completable_order) do
          order = create(:order_with_line_items, store: store, user: user)
          Spree.checkout_advance_service.call(order: order)
          payment_method = create(:check_payment_method, stores: [store])
          create(:payment, order: order, amount: order.total, payment_method: payment_method, state: 'checkout')
          order.reload
        end
        let!(:_ensure_order) { completable_order }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { completable_order.prefixed_id }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('or_')
          expect(data['completed_at']).to be_present
        end
      end

      response '422', 'cannot complete' do
        let!(:order) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { order.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
