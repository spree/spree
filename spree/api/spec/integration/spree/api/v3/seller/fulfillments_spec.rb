# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Fulfillments API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one —
  # fulfilling is gated on the `fulfillments` permission.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:order) { create(:order_ready_to_ship, store: store, seller: seller) }
  let(:fulfillment) { order.fulfillments.first }

  path '/api/v3/seller/orders/{order_id}/fulfillments' do
    parameter name: :order_id, in: :path, type: :string, description: 'Prefixed order ID'

    get 'List fulfillments' do
      tags 'Fulfillments'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The parcels this seller owes on one order.

        Reached through the order, which is itself fetched through the acting
        seller — so a fulfillment on somebody else's order is unreachable
        whatever ids are sent.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'fulfillments listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Fulfillment' } }
               },
               required: %w[data]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(fulfillment.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/fulfillments/{id}/fulfill' do
    parameter name: :order_id, in: :path, type: :string, description: 'Prefixed order ID'
    parameter name: :id, in: :path, type: :string, description: 'Prefixed fulfillment ID'

    patch 'Fulfill (ship) a parcel' do
      tags 'Fulfillments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Marks the parcel shipped.

        This is the same workflow the marketplace operator runs, so the
        customer's dispatch email, the label purchase and any extension hooks
        happen exactly as they would had the operator shipped it.

        `items` narrows the dispatch to part of what the fulfillment holds; the
        remainder splits onto a new one. Omit it to ship the lot.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          tracking: { type: :string, description: 'Carrier tracking number' },
          tracking_carrier: { type: :string, description: 'Carrier name' },
          notify_customer: { type: :boolean, description: 'Send the dispatch email (default true)' },
          items: {
            type: :array,
            description: 'Ship only these lines; the rest split onto a new fulfillment',
            items: {
              type: :object,
              properties: {
                item_id: { type: :string, description: 'Prefixed line item ID' },
                quantity: { type: :integer }
              },
              required: %w[item_id quantity]
            }
          }
        }
      }

      response '200', 'parcel shipped' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { fulfillment.prefixed_id }
        let(:body) { { tracking: 'TRACK-1' } }

        schema '$ref' => '#/components/schemas/Fulfillment'

        run_test! do
          expect(fulfillment.reload).to be_fulfilled
          expect(fulfillment.tracking).to eq('TRACK-1')
        end
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/fulfillments/{id}' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Update tracking' do
      tags 'Fulfillments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Adds or corrects the tracking number and its carrier.

        Deliberately narrow: where a parcel ships from and which service
        carries it are the marketplace's arrangements, so they are not
        editable here.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tracking: { type: :string, nullable: true },
          tracking_carrier: { type: :string, nullable: true }
        }
      }

      response '200', 'tracking recorded' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { fulfillment.prefixed_id }
        let(:body) { { tracking: 'TRACK-2', tracking_carrier: 'ups' } }

        schema '$ref' => '#/components/schemas/Fulfillment'

        run_test! do
          expect(fulfillment.reload.tracking).to eq('TRACK-2')
        end
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/fulfillments/{id}/cancel' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Cancel a parcel' do
      tags 'Fulfillments'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        A parcel this seller is not going to send after all. The goods go back
        on the shelf and the carrier is stood down.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'parcel canceled' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { fulfillment.prefixed_id }

        schema '$ref' => '#/components/schemas/Fulfillment'

        run_test! do
          expect(fulfillment.reload).to be_canceled
        end
      end
    end
  end

  path '/api/v3/seller/orders/{order_id}/fulfillments/{id}/mark_delivered' do
    parameter name: :order_id, in: :path, type: :string
    parameter name: :id, in: :path, type: :string

    patch 'Confirm delivery' do
      tags 'Fulfillments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Confirms the customer received the goods — the point the returns
        window runs from, and recordable by hand for a seller posting parcels
        without a carrier integration.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          delivered_at: { type: :string, nullable: true },
          notify_customer: { type: :boolean }
        }
      }

      response '200', 'delivery confirmed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:order_id) { order.prefixed_id }
        let(:id) { fulfillment.prefixed_id }
        let(:body) { {} }

        before { Spree.fulfillment_fulfill_workflow.call(fulfillment: fulfillment) }

        schema '$ref' => '#/components/schemas/Fulfillment'

        run_test! do
          expect(fulfillment.reload).to be_delivered
        end
      end
    end
  end

  path '/api/v3/seller/tracking_carriers' do
    get 'List tracking carriers' do
      tags 'Fulfillments'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The carriers a tracking number can be pinned to, from the registry —
        so a carrier an extension adds appears without a client change.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'carriers listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: { id: { type: :string }, name: { type: :string } },
                     required: %w[id name]
                   }
                 }
               },
               required: %w[data]

        run_test!
      end
    end
  end
end
