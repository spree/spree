# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Order Returns API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:order) { create(:shipped_order, store: store, customer: user) }
  let!(:return_record) { create(:return, order: order) }

  path '/api/v3/store/orders/{order_id}/returns' do
    parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'

    get 'List returns' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The returns opened on one of the customer\'s orders, newest first. Accessible via JWT or the order token header for guests.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      filter_parameters_for

      response '200', 'returns listed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Return')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to eq([return_record.prefixed_id])
        end
      end
    end

    post 'Open a return' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Opens a return for shipped units of one of the customer\'s orders. Approving, receiving and refunding it are the merchant\'s. Accessible via JWT or the order token header for guests.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      request_body_for

      response '201', 'return opened' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:returnable_order) { create(:shipped_order, store: store, customer: user) }
        let(:order_id) { returnable_order.prefixed_id }
        let(:return_reason) { create(:return_reason, store: store) }
        let(:body) do
          {
            items: [{ fulfillment_item_id: returnable_order.fulfillment_items.first.prefixed_id, quantity: 1 }],
            reason_id: return_reason.prefixed_id,
            memo: 'Wrong size'
          }
        end

        schema '$ref' => '#/components/schemas/Return'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('requested')
        end
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/returns/{id}/cancel' do
    parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Return prefixed ID'

    patch 'Withdraw a return request' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws a return the customer opened, while the merchant has not acted on it yet (`cancelable` on the return). ' \
                  'Accessible via JWT or the order token header for guests.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'

      let(:'x-spree-api-key') { api_key.token }
      let(:Authorization) { "Bearer #{jwt_token}" }
      let(:order_id) { order.prefixed_id }

      response '200', 'return withdrawn' do
        let(:id) { return_record.prefixed_id }

        schema '$ref' => '#/components/schemas/Return'

        run_test! do |response|
          expect(JSON.parse(response.body)).to include('status' => 'canceled', 'cancelable' => false)
        end
      end

      response '422', 'the merchant has already acted on it' do
        let(:id) do
          return_record.update_columns(status: 'approved', approved_at: Time.current)
          return_record.prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          expect(response.body).to include('can no longer be withdrawn')
          expect(return_record.reload.status).to eq('approved')
        end
      end
    end
  end
end
