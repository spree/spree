# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Cart Discount Codes API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user) }
  let(:cart_id) { order.prefixed_id }

  path '/api/v3/store/carts/{cart_id}/discount_codes' do
    post 'Apply discount code' do
      tags 'Carts'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Applies a promotion discount code to the cart. The code is matched case-insensitively.

        For gift cards, use the dedicated `POST /carts/{cart_id}/gift_cards` endpoint instead.
      DESC

      sdk_example 'carts/discount-codes-apply'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID (e.g., cart_abc123)'
      parameter name: 'Idempotency-Key', in: :header, type: :string, required: false,
                description: 'Unique key for request idempotency.'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          code: { type: :string, example: 'SAVE10', description: 'Promotion discount code to apply' }
        },
        required: %w[code]
      }

      response '201', 'discount code applied' do
        let!(:promotion) { create(:promotion_with_item_adjustment, code: 'SAVE10', stores: [store]) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { code: 'SAVE10' } }

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(order.number)
        end
      end

      response '422', 'invalid discount code' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:body) { { code: 'NONEXISTENT' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
        end
      end
    end
  end

  path '/api/v3/store/carts/{cart_id}/discount_codes/{id}' do
    delete 'Remove discount code' do
      tags 'Carts'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes a previously applied discount code from the cart. The ID is the discount code string itself.'

      sdk_example 'carts/discount-codes-remove'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :cart_id, in: :path, type: :string, required: true, description: 'Cart prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'The discount code string to remove (e.g., SAVE10)'
      parameter name: 'x-spree-token', in: :header, type: :string, required: false,
                description: 'Order token for guest access'

      response '200', 'discount code removed' do
        let!(:promotion) { create(:promotion_with_item_adjustment, code: 'REMOVE10', stores: [store]) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) do
          order.coupon_code = 'REMOVE10'
          Spree::PromotionHandler::Coupon.new(order).apply
          'REMOVE10'
        end

        schema '$ref' => '#/components/schemas/Cart'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('cart_')
          expect(data['number']).to eq(order.number)
        end
      end

      response '422', 'discount code not found on cart' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:id) { 'NONEXISTENT' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
