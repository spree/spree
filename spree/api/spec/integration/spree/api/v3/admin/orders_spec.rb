# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Orders API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order, store: store, state: 'cart', email: 'test@example.com') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders' do
    get 'List orders' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of orders for the current store.'
      admin_scope :read, :orders

      admin_sdk_example 'orders/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort field (e.g., created_at, -created_at, completed_at)'
      filter_parameters_for
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., items, fulfillments, payments, customer, discounts, billing_address, shipping_address). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., number,total,status,completed_at). id is always included.'

      response '200', 'orders found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['meta']).to include('page', 'limit', 'count', 'pages')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a draft order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]

      admin_sdk_example 'orders/create'

      description <<~DESC
        Creates a new draft order in one shot. Customer, items, addresses, currency,
        market, channel, locale, notes, metadata, and a coupon code can all be
        provided inline.

        Setting `preferred_stock_location_id` pins the order's preferred fulfillment
        location — Order Routing's built-in `PreferredLocation` rule consumes it
        when picking which stock location ships each shipment.

        Invalid coupon codes are non-fatal — the order is created and the failure
        is reported on the service result (not in the API response body for now).
      DESC
      admin_scope :write, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      request_body_for

      response '201', 'order created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: 'new-order@example.com' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('new-order@example.com')
        end
      end

      response '201', 'order created with preferred_stock_location_id' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:preferred_location) { create(:stock_location, name: 'Preferred', default: false) }
        let(:body) do
          {
            email: 'pinned@example.com',
            preferred_stock_location_id: preferred_location.prefixed_id
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['preferred_stock_location_id']).to eq(preferred_location.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{id}' do
    let(:id) { order.prefixed_id }

    get 'Show an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns full order details including admin-only fields.'
      admin_scope :read, :orders

      admin_sdk_example 'orders/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID (e.g., or_xxx)'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., items, fulfillments, payments, customer, discounts, billing_address, shipping_address). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., number,total,status,completed_at). id is always included.'

      response '200', 'order found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(order.prefixed_id)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'or_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates an order. Supports updating email, addresses, special instructions, and line items.'
      admin_scope :write, :orders

      admin_sdk_example 'orders/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'
      request_body_for

      response '200', 'order updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { email: 'updated@example.com' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['email']).to eq('updated@example.com')
        end
      end
    end

    delete 'Delete a draft order' do
      tags 'Orders'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a draft order. Completed orders cannot be deleted.'
      admin_scope :write, :orders

      admin_sdk_example 'orders/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '204', 'order deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{id}/complete' do
    patch 'Complete an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Completes an order in the `confirm` state, marking it as placed.

        Set `notify_customer: true` to send the order confirmation email.

        On a marketplace, an order holding several sellers' goods becomes one
        order per seller, and the response is the order group they belong to
        with those orders nested inside it.
      DESC
      admin_scope :write, :orders

      admin_sdk_example 'orders/complete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'
      request_body_for

      response '200', 'order completed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:order_ready_to_ship, store: store) }
        let(:id) { order.prefixed_id }
        let(:body) { { notify_customer: false } }

        run_test!
      end

      response '422', 'order cannot be completed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:order_with_line_items, store: store) }
        let(:id) { order.prefixed_id }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{id}/cancel' do
    patch 'Cancel an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Cancels a completed order.

        `cancel_reason_id` records why, from the store's own cancellation-reason
        vocabulary (`/admin/order_cancellation_reasons`), and `cancel_note` is a
        staff-facing note; both are shown on the order afterwards.

        Stock is always released — the goods are not going out either way — and
        every payment is settled at the gateway, which releases an
        authorization it never drew on and refunds a charge it cannot release.

        `refund_payments` and `refund_amount` govern the shared payment of a
        split checkout, where one payment covers several orders: they decide
        whether this order's share comes back, and how much of it. A
        `refund_amount` on an ordinary order is refused with a 422.

        Set `notify_customer: true` to send the order cancellation email.
      DESC
      admin_scope :write, :orders

      admin_sdk_example 'orders/cancel'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'
      request_body_for

      response '200', 'order canceled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:completed_order_with_totals, store: store) }
        let(:id) { order.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{id}/approve' do
    patch 'Approve an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Approves an order (e.g., for fraud review).'
      admin_scope :write, :orders

      admin_sdk_example 'orders/approve'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'order approved' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:completed_order_with_totals, store: store) }
        let(:id) { order.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['approved_at']).to be_present
        end
      end
    end
  end

  path '/api/v3/admin/orders/{id}/resend_confirmation' do
    post 'Resend confirmation email' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Publishes the order.completed event to trigger confirmation email delivery.'
      admin_scope :write, :orders

      admin_sdk_example 'orders/resend-confirmation'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'confirmation resent' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:order) { create(:completed_order_with_totals, store: store) }
        let(:id) { order.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(order.prefixed_id)
        end
      end
    end
  end
end
