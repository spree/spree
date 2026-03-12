# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Customer Orders API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }

  path '/api/v3/store/customer/orders' do
    get 'List orders' do
      tags 'Customer'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a paginated list of completed orders for the authenticated customer.'

      sdk_example <<~JS
        const orders = await client.customer.orders.list({
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true

      response '200', 'orders listed' do
        let!(:completed_order) { create(:completed_order_with_totals, store: store, user: user) }
        let!(:incomplete_order) { create(:order_with_line_items, store: store, user: user) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

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

  path '/api/v3/store/customer/orders/{id}' do
    get 'Get an order' do
      tags 'Customer'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single completed order for the authenticated customer.'

      sdk_example <<~JS
        const order = await client.customer.orders.get('or_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'

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
