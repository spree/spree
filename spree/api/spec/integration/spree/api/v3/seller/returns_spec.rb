# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Returns API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # Returns are a subject of the `orders` permission, so the seeded role
  # rather than the shared context's products-only one.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1) }
  let(:fulfillment_item) { order.fulfillment_items.first }

  let(:return_record) do
    Spree::Returns::Create.call(
      order: order,
      items: [{ fulfillment_item: order.fulfillment_items.first, quantity: 1 }]
    ).value
  end

  path '/api/v3/seller/orders/{order_id}/returns' do
    parameter name: :order_id, in: :path, type: :string, description: 'Prefixed order ID'

    get 'List returns' do
      tags 'Returns'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Goods coming back on one of this seller's orders.

        Reached through the order, which is itself fetched through the acting
        seller — so a return on somebody else's order is unreachable whatever
        ids are sent.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'returns listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }

        before { return_record }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Return' } }
               },
               required: %w[data]

        run_test!
      end
    end

    post 'Open a return' do
      tags 'Returns'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Takes goods back on one of this seller's orders.

        The units are addressed by fulfillment item and resolved through the
        order, so only what this seller actually shipped can come back. An
        optional stock location says which of the seller's own shelves it
        returns to.
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
                quantity: { type: :integer }
              },
              required: %w[fulfillment_item_id quantity]
            }
          },
          reason_id: { type: :string, nullable: true },
          stock_location_id: { type: :string, nullable: true },
          memo: { type: :string, nullable: true }
        },
        required: %w[items]
      }

      response '201', 'return opened' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:body) do
          { items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 1 }] }
        end

        schema '$ref' => '#/components/schemas/Return'

        run_test!
      end

      response '422', 'more than was shipped' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:body) do
          { items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, quantity: 99 }] }
        end

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/returns/{id}/approve' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Approve a return' do
      tags 'Returns'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Agrees the goods may come back.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'return approved' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { return_record.prefixed_id }

        schema '$ref' => '#/components/schemas/Return'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/returns/{id}/receive' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Receive a return' do
      tags 'Returns'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Records what actually arrived, and whether it can be sold again.

        Omitting `items` receives everything as requested and resellable.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                return_line_item_id: { type: :string },
                quantity: { type: :integer },
                resellable: { type: :boolean }
              },
              required: %w[return_line_item_id quantity]
            }
          }
        }
      }

      response '200', 'return received' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { return_record.prefixed_id }
        let(:body) { {} }

        before { Spree::Returns::Approve.call(return_record: return_record) }

        schema '$ref' => '#/components/schemas/Return'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/returns/{id}/refund' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Refund a return' do
      tags 'Returns'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Gives the customer their money back.

        The seller is merchant of record for their own child order, so this is
        theirs to do. The amount is bounded by what the return is owed and, on
        a basket split between sellers, by this order's share of the payment —
        never a sibling's.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          amount: { type: :string, nullable: true },
          refund_method: { type: :string, enum: %w[original_payment store_credit] }
        }
      }

      response '200', 'return refunded' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { return_record.prefixed_id }
        let(:body) { { refund_method: 'store_credit' } }

        before do
          Spree::Returns::Approve.call(return_record: return_record)
          Spree::Returns::Receive.call(return_record: return_record)
        end

        schema '$ref' => '#/components/schemas/Return'

        run_test!
      end

      response '422', 'more than the return is owed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { return_record.prefixed_id }
        let(:body) { { refund_method: 'store_credit', amount: '10000.0' } }

        before do
          Spree::Returns::Approve.call(return_record: return_record)
          Spree::Returns::Receive.call(return_record: return_record)
        end

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/returns/{id}/cancel' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Cancel a return' do
      tags 'Returns'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Calls the return off.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'return canceled' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { return_record.prefixed_id }

        schema '$ref' => '#/components/schemas/Return'

        run_test!
      end
    end
  end

  path '/api/v3/seller/return_reasons' do
    get 'List return reasons' do
      tags 'Returns'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Why goods come back, as the marketplace defines it.

        Read-only: the vocabulary is the operator's, and a seller picks from
        it. Retired reasons are left out.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'reasons listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        before { create(:return_reason, store: store, name: 'Damaged in transit') }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Reason' } }
               },
               required: %w[data]

        run_test!
      end
    end
  end
end
