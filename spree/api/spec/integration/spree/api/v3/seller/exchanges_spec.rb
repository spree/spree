# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Exchanges API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1) }
  let(:fulfillment_item) { order.fulfillment_items.first }
  let(:replacement) { create(:variant, seller: seller) }

  let(:exchange) do
    Spree::Exchanges::Create.call(
      order: order,
      items: [{ fulfillment_item: fulfillment_item, new_variant: replacement, quantity: 1 }]
    ).value
  end

  path '/api/v3/seller/orders/{order_id}/exchanges' do
    parameter name: :order_id, in: :path, type: :string, description: 'Prefixed order ID'

    get 'List exchanges' do
      tags 'Exchanges'
      produces 'application/json'
      security [bearer_auth: []]
      description "Goods swapped for different ones on one of this seller's orders."

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'exchanges listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }

        before { exchange }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Exchange' } }
               },
               required: %w[data]

        run_test!
      end
    end

    post 'Open an exchange' do
      tags 'Exchanges'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Swaps goods for different ones.

        The replacement comes from this seller's own catalogue: it is stock
        they will send, so a variant belonging to another seller is not theirs
        to promise and reads as missing.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                fulfillment_item_id: { type: :string },
                new_variant_id: { type: :string },
                quantity: { type: :integer }
              },
              required: %w[fulfillment_item_id new_variant_id quantity]
            }
          },
          reason_id: { type: :string, nullable: true },
          stock_location_id: { type: :string, nullable: true },
          memo: { type: :string, nullable: true }
        },
        required: %w[items]
      }

      response '201', 'exchange opened' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:body) do
          {
            items: [{
              fulfillment_item_id: fulfillment_item.prefixed_id,
              new_variant_id: replacement.prefixed_id,
              quantity: 1
            }]
          }
        end

        schema '$ref' => '#/components/schemas/Exchange'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/exchanges/{id}/fulfill' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Send the replacement' do
      tags 'Exchanges'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Sends the replacement goods, settling any price difference at the same
        time — which is why it takes a refund method.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          refund_method: { type: :string, enum: %w[original_payment store_credit] }
        }
      }

      response '200', 'replacement sent' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { exchange.prefixed_id }
        let(:body) { {} }

        before do
          Spree::Exchanges::Approve.call(exchange: exchange)
          Spree::Exchanges::Receive.call(exchange: exchange)
        end

        schema '$ref' => '#/components/schemas/Exchange'

        run_test!
      end
    end
  end
end
