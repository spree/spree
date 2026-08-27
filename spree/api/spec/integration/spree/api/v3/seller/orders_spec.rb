# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Orders API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one —
  # orders are gated on the `orders` permission, which that role omits.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:order) { create(:completed_order_with_totals, store: store, seller: seller) }

  path '/api/v3/seller/orders' do
    get 'List orders' do
      tags 'Orders'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        What this seller has sold.

        On a marketplace a basket spanning several sellers is split into one
        order each, so these are the seller's own orders rather than a filtered
        view of somebody else's — another seller's order is never reachable,
        whatever id is sent.

        Checkouts still in flight are left out: until one completes it is
        nobody's order.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :sort, in: :query, type: :string, required: false, description: 'Sort field; prefix with `-` for descending'

      response '200', 'orders listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/Order' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['number'] }).to include(order.number)
        end
      end
    end
  end

  path '/api/v3/seller/orders/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Prefixed order ID'

    get 'Get an order' do
      tags 'Orders'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        One order, as the seller needs it to pack and post the parcel: the
        lines with their SKUs, where it ships to, and a fulfillment per parcel.

        How the customer paid the marketplace is deliberately absent — that is
        between the buyer and the operator.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'order found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { order.prefixed_id }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do |response|
          expect(JSON.parse(response.body)['number']).to eq(order.number)
        end
      end

      response '404', "another seller's order" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) do
          create(:completed_order_with_totals,
                 store: store, seller: create(:seller, :approved, store: store)).prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/orders/{id}/cancel' do
    parameter name: :id, in: :path, type: :string, description: 'Prefixed order ID'

    patch 'Cancel an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Withdraws from an order this seller cannot fulfil.

        Restocking and any refund are the cancellation's own concern, so a
        seller cannot cancel without the money and the stock following.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, required: false, schema: {
        type: :object,
        properties: {
          notify_customer: { type: :boolean, description: 'Email the customer about the cancellation' }
        }
      }

      response '200', 'order canceled' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { order.prefixed_id }
        let(:body) { {} }

        schema '$ref' => '#/components/schemas/Order'

        run_test! do
          expect(order.reload).to be_canceled
        end
      end
    end
  end
end
