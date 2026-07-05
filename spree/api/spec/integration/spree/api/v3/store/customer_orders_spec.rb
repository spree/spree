# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Customer Orders API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }

  path '/api/v3/store/customers/me/orders' do
    get 'List orders' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of completed orders for the authenticated customer.'

      sdk_example 'customer-orders/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number (default: 1)'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of results per page (default: 25, max: 100)'
      parameter name: :sort, in: :query, type: :string, required: false,
                description: 'Sort order. Prefix with - for descending. Values: completed_at, -completed_at, total, -total, number, -number'
      parameter name: 'q[completed_at_gt]', in: :query, type: :string, required: false,
                description: 'Filter by completed after date (ISO 8601)'
      parameter name: 'q[completed_at_lt]', in: :query, type: :string, required: false,
                description: 'Filter by completed before date (ISO 8601)'
      parameter name: 'q[number_eq]', in: :query, type: :string, required: false,
                description: 'Filter by exact order number (e.g., R123456)'
      parameter name: 'q[state_eq]', in: :query, type: :string, required: false,
                description: 'Filter by order state (complete, returned, canceled)'
      parameter name: 'q[payment_state_eq]', in: :query, type: :string, required: false,
                description: 'Filter by payment state (paid, balance_due, credit_owed, void, failed)'
      parameter name: 'q[total_gteq]', in: :query, type: :number, required: false,
                description: 'Filter by minimum total'
      parameter name: 'q[total_lteq]', in: :query, type: :number, required: false,
                description: 'Filter by maximum total'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (items, fulfillments, payments, discounts, billing_address, shipping_address, gift_card). Use "none" to skip associations.'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., total,amount_due,item_count). id is always included.'

      response '200', 'orders listed' do
        let!(:completed_order) { create(:completed_order_with_totals, store: store, user: user) }
        let!(:incomplete_order) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Order' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)
          ids = data['data'].map { |o| o['id'] }
          expect(ids).to include(completed_order.prefixed_id)
          expect(ids).not_to include(incomplete_order.prefixed_id)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { '' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/customers/me/orders/{id}' do
    get 'Get an order' do
      tags 'Customers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single completed order for the authenticated customer.'

      sdk_example 'customer-orders/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (items, fulfillments, payments, discounts, billing_address, shipping_address, gift_card). Use "none" to skip associations.'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., total,amount_due,item_count). id is always included.'

      response '200', 'order found' do
        let(:completed_order) { create(:completed_order_with_totals, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { completed_order.to_param }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('or_')
          expect(data['number']).to eq(completed_order.number)
          expect(data['completed_at']).to be_present
        end
      end

      response '404', 'order belongs to another user' do
        let(:other_user) { create(:user) }
        let(:other_order) { create(:completed_order_with_totals, store: store, user: other_user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { other_order.to_param }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
