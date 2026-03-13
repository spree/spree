# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Store Credits API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let(:user) { create(:user_with_addresses) }
  let!(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/store_credits' do
    post 'Apply store credit' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Applies store credit to the cart during checkout.'

      sdk_example <<~JS
        const cart = await client.carts.storeCredits.apply('cart_abc123', 10.0, {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'
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
        let(:body) { { amount: 10 } }

        before do
          store_credit_payment_method
          store_credit
        end

        schema '$ref' => '#/components/schemas/Cart'

        run_test!
      end

      response '422', 'no store credit available' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Remove store credit' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes store credit from the cart.'

      sdk_example <<~JS
        const cart = await client.carts.storeCredits.remove('cart_abc123', {
          bearerToken: '<token>',
        })
      JS

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: true
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false

      response '200', 'store credit removed' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }

        schema '$ref' => '#/components/schemas/Cart'

        run_test!
      end
    end
  end
end
