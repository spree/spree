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

      seller_sdk_example 'order-exchanges/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      filter_parameters_for

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

      seller_sdk_example 'order-exchanges/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

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

  path '/api/v3/seller/orders/{order_id}/exchanges/{id}/receive' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Receive an exchange' do
      tags 'Exchanges'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Records the goods coming back. Send the rows that actually arrived for
        a partial or damaged receipt; omit them to receive everything.
      DESC

      seller_sdk_example 'order-exchanges/receive'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for(required: false)

      response '200', 'exchange received' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { exchange.prefixed_id }
        let(:body) do
          {
            items: [
              { exchange_line_item_id: exchange.exchange_line_items.first.prefixed_id, quantity: 1, resellable: true }
            ]
          }
        end

        before { Spree::Exchanges::Approve.call(exchange: exchange) }

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('received')
        end
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

      seller_sdk_example 'order-exchanges/fulfill'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for(required: false)

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

  path '/api/v3/seller/orders/{order_id}/exchanges/{id}/cancel' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Cancel an exchange' do
      tags 'Exchanges'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Withdraws an exchange before the goods come back.'

      seller_sdk_example 'order-exchanges/cancel'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for(required: false)

      response '200', 'exchange canceled' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { exchange.prefixed_id }
        let(:body) { { reason: 'Customer kept the original' } }

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
        end
      end
    end
  end
end
