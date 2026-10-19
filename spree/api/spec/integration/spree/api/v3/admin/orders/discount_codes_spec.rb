# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Discount Codes API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_with_line_items, store: store, line_items_price: 50) }
  let!(:promotion) do
    create(:promotion_with_item_total_rule, :with_line_item_adjustment,
           code: 'save5', kind: :coupon_code, store: store,
           item_total_threshold_amount: 30, adjustment_rate: 5)
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }

  path '/api/v3/admin/orders/{order_id}/discount_codes' do
    let(:order_id) { order.prefixed_id }

    post 'Apply a discount code' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Applies a discount code to a draft order and returns the order. A real code the order does not yet qualify for is kept and applies once it does. ' \
                  'Completed orders refuse codes; change their discounts through manual discounts instead.'
      admin_scope :write, :orders

      admin_sdk_example 'orders/discount-codes-apply'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      request_body_for

      response '201', 'discount code applied' do
        let(:body) { { code: 'SAVE5' } }

        run_test! do |response|
          expect(JSON.parse(response.body)['coupon_code']).to eq('save5')
        end
      end

      response '422', 'unknown discount code' do
        let(:body) { { code: 'bogus' } }

        run_test!
      end
    end
  end
end
