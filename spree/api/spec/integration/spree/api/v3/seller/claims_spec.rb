# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Claims API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:order) { create(:shipped_order, store: store, seller: seller, line_items_count: 1) }
  let(:line_item) { order.line_items.first }

  let(:claim) do
    Spree::Claims::Create.call(order: order, items: [{ line_item: line_item, quantity: 1 }]).value
  end

  path '/api/v3/seller/orders/{order_id}/claims' do
    parameter name: :order_id, in: :path, type: :string, description: 'Prefixed order ID'

    get 'List claims' do
      tags 'Claims'
      produces 'application/json'
      security [bearer_auth: []]
      description "Problems reported on one of this seller's orders."

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'claims listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }

        before { claim }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Claim' } }
               },
               required: %w[data]

        run_test!
      end
    end

    post 'Open a claim' do
      tags 'Claims'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Reports that something went wrong with a delivery, to be put right
        without necessarily asking for the goods back.

        A replacement variant, if one is offered, comes from this seller's own
        catalogue — a rival's is not theirs to promise.
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
                line_item_id: { type: :string },
                quantity: { type: :integer },
                description: { type: :string, nullable: true },
                send_replacement: { type: :boolean },
                replacement_variant_id: { type: :string, nullable: true },
                refund_amount: { type: :string, nullable: true }
              },
              required: %w[line_item_id quantity]
            }
          },
          reason_id: { type: :string, nullable: true },
          memo: { type: :string, nullable: true }
        },
        required: %w[items]
      }

      response '201', 'claim opened' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:body) do
          {
            items: [
              { line_item_id: line_item.prefixed_id, quantity: 1, description: 'Arrived broken' }
            ]
          }
        end

        schema '$ref' => '#/components/schemas/Claim'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/claims/{id}/approve' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Approve a claim' do
      tags 'Claims'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Accepts that the claim is good.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'claim approved' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { claim.prefixed_id }

        schema '$ref' => '#/components/schemas/Claim'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/claims/{id}/resolve' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Resolve a claim' do
      tags 'Claims'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Puts the claim right: money back, a replacement shipment, or both.

        A refund is bounded by this order's share of the payment, so one
        seller can never settle out of a sibling's money.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          resolution: { type: :string, enum: %w[refund replacement refund_and_replacement] },
          refund_method: { type: :string, enum: %w[original_payment store_credit] },
          amount: { type: :string, nullable: true },
          replacement_line_item_ids: { type: :array, items: { type: :string } }
        },
        required: %w[resolution]
      }

      response '200', 'claim resolved' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { claim.prefixed_id }
        let(:body) { { resolution: 'refund', refund_method: 'store_credit', amount: '5.0' } }

        before { Spree::Claims::Approve.call(claim: claim) }

        schema '$ref' => '#/components/schemas/Claim'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/claims/{id}/deny' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Deny a claim' do
      tags 'Claims'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Turns the claim down.'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'claim denied' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { claim.prefixed_id }

        schema '$ref' => '#/components/schemas/Claim'

        run_test!
      end
    end
  end

  path '/api/v3/seller/claim_reasons' do
    get 'List claim reasons' do
      tags 'Claims'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What can go wrong with a delivery, as the marketplace defines it.

        Read-only: a seller picks from the operator's vocabulary.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'reasons listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        before { create(:claim_reason, store: store, name: 'Arrived damaged') }

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
