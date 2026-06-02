# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Store Credits API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:customer) { create(:user) }
  let!(:order) { create(:order_with_line_items, store: store, user: customer) }
  let!(:store_credit) { create(:store_credit, store: store, user: customer, amount: 50.00) }
  let!(:store_credit_payment_method) { create(:store_credit_payment_method) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/store_credits' do
    let(:order_id) { order.prefixed_id }

    post "Apply customer's store credit to an order" do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Applies the order customer\'s available store credit. ' \
                  'When `amount` is omitted, applies up to the order outstanding balance.'
      admin_scope :write, :store_credits

      admin_sdk_example 'order-store-credits/apply'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :number, description: 'Optional explicit amount; defaults to order outstanding balance' }
        }
      }

      response '201', 'store credit applied' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { {} }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(order.prefixed_id)
        end
      end
    end

    delete "Remove store credit from an order" do
      tags 'Orders'
      security [api_key: [], bearer_auth: []]
      description "Removes any applied store credit from the order."
      admin_scope :write, :store_credits

      admin_sdk_example 'order-store-credits/remove'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '204', 'store credit removed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        before { Spree.checkout_add_store_credit_service.call(order: order) }

        run_test!
      end
    end
  end
end
