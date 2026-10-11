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
  end
end
