# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Gift Cards API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_with_line_items, store: store, state: 'cart') }
  let!(:gift_card) { create(:gift_card, store: store) }
  let!(:store_credit_payment_method) { create(:store_credit_payment_method) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/gift_cards' do
    let(:order_id) { order.prefixed_id }

    post 'Apply a gift card to an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Applies a gift card by code to the order. Returns the gift card.'
      admin_scope :write, :gift_cards

      admin_sdk_example 'order-gift-cards/apply'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[code],
        properties: {
          code: { type: :string, description: 'Gift card code', example: 'GIFT-XXXX-YYYY' }
        }
      }

      response '201', 'gift card applied' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { code: gift_card.code } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(gift_card.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/gift_cards/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { gift_card.prefixed_id }

    delete 'Remove a gift card from an order' do
      tags 'Orders'
      security [api_key: [], bearer_auth: []]
      description 'Removes the gift card from the order.'
      admin_scope :write, :gift_cards

      admin_sdk_example 'order-gift-cards/remove'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Gift card ID'

      response '204', 'gift card removed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before { order.update_column(:gift_card_id, gift_card.id) }

        run_test!
      end
    end
  end
end
