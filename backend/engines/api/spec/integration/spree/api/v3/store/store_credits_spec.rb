# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Store Credits API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }
  let!(:order) { create(:order_with_line_items, store: store, user: user) }

  path '/api/v3/store/orders/{order_id}/store_credits' do
    post 'Add store credit' do
      tags 'Checkout'
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
          amount: { type: :number, example: 10.0, description: 'Amount to apply (optional - defaults to max available)' }
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
      tags 'Checkout'
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
