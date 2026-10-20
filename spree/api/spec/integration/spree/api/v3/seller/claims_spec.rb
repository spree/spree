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

      seller_sdk_example 'order-claims/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      filter_parameters_for

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

      seller_sdk_example 'order-claims/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

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

  path '/api/v3/seller/orders/{order_id}/claims/{id}' do
    parameter name: :order_id, in: :path, type: :string, description: 'Prefixed order ID'
    parameter name: :id, in: :path, type: :string, description: 'Prefixed claim ID'

    get 'Show a claim' do
      tags 'Claims'
      produces 'application/json'
      security [bearer_auth: []]
      description "One problem reported on one of this seller's orders, with the items it covers and the reason given."

      seller_sdk_example 'order-claims/get'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'claim found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { claim.prefixed_id }

        schema '$ref' => '#/components/schemas/Claim'

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(claim.prefixed_id)
        end
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

      seller_sdk_example 'order-claims/approve'

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

      seller_sdk_example 'order-claims/resolve'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

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
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Turns the claim down.'

      seller_sdk_example 'order-claims/deny'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for(required: false)

      response '200', 'claim denied' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { claim.prefixed_id }
        let(:body) { { reason: 'Reported after the claim window closed' } }

        schema '$ref' => '#/components/schemas/Claim'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/claims/{id}/cancel' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Cancel a claim' do
      tags 'Claims'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Withdraws a claim that is no longer needed.'

      seller_sdk_example 'order-claims/cancel'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for(required: false)

      response '200', 'claim canceled' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { claim.prefixed_id }
        let(:body) { { reason: 'Customer found the missing item' } }

        schema '$ref' => '#/components/schemas/Claim'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
        end
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

      seller_sdk_example 'claim-reasons/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      filter_parameters_for

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
