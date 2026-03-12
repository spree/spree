# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Orders API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }

  path '/api/v3/store/orders/{id}' do
    get 'Get an order' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single completed order by prefixed ID. Accessible via JWT (authenticated users) or order token header (guests).'

      sdk_example <<~JS
        const order = await client.orders.get('or_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order prefixed ID'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'

      response '200', 'order found (authenticated)' do
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
          expect(data).not_to have_key('token')
          expect(data).not_to have_key('checkout_steps')
          expect(data).not_to have_key('state_lock_version')
        end
      end

      response '200', 'order found (guest via order token)' do
        let(:guest_order) { create(:completed_order_with_totals, store: store, user: nil, email: 'guest@example.com') }
        let(:'x-spree-api-key') { api_key.token }
        let(:id) { guest_order.to_param }
        let(:'x-spree-token') { guest_order.token }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('or_')
          expect(data['number']).to eq(guest_order.number)
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'or_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', 'incomplete order not accessible' do
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
