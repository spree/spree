# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Coupon Codes API', type: :request, swagger_doc: 'api-reference/store.yaml' do
  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user) }

  path '/api/v3/store/orders/{order_id}/coupon_codes' do
    post 'Apply coupon code' do
      tags 'Cart'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Applies a coupon code to the order. Supports both promotion coupon codes and gift card codes.
        The code is matched case-insensitively.
      DESC

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :order_token, in: :query, type: :string, required: false,
                description: 'Order token for guest access'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          code: { type: :string, example: 'SAVE10', description: 'Coupon code or gift card code to apply' }
        },
        required: %w[code]
      }

      response '201', 'coupon code applied (promotion)' do
        let!(:promotion) { create(:promotion_with_item_adjustment, code: 'SAVE10', stores: [store]) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:body) { { code: 'SAVE10' } }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(order.number)
        end
      end

      response '201', 'coupon code applied (gift card)' do
        let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'giftcode1') }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:body) { { code: 'giftcode1' } }

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(order.number)
        end
      end

      response '422', 'invalid coupon code' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:body) { { code: 'NONEXISTENT' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
        end
      end

      response '404', 'order not found' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { 'or_nonexistent' }
        let(:body) { { code: 'SAVE10' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/store/orders/{order_id}/coupon_codes/{id}' do
    delete 'Remove coupon code' do
      tags 'Cart'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Removes a previously applied coupon code from the order.'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: 'Authorization', in: :header, type: :string, required: false,
                description: 'Bearer token for authenticated customers'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Order promotion ID'
      parameter name: :order_token, in: :query, type: :string, required: false,
                description: 'Order token for guest access'

      response '200', 'coupon code removed' do
        let!(:promotion) { create(:promotion_with_item_adjustment, code: 'REMOVE10', stores: [store]) }
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) do
          order.coupon_code = 'REMOVE10'
          Spree::PromotionHandler::Coupon.new(order).apply
          op = order.order_promotions.find_by(promotion: promotion)
          "op_#{Spree::PrefixedId::SQIDS.encode([op.id])}"
        end

        schema '$ref' => '#/components/schemas/StoreOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['number']).to eq(order.number)
        end
      end

      response '404', 'coupon code not found on order' do
        let(:'x-spree-api-key') { api_key.token }
        let(:'Authorization') { "Bearer #{jwt_token}" }
        let(:order_id) { order.to_param }
        let(:id) { 'op_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
