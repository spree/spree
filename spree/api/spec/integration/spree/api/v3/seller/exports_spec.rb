# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Exports API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The shared context's role reads products only; an orders export is gated on
  # `read_orders`, which is the scope of what it contains.
  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[read_orders read_products])
  end

  let!(:order) { create(:completed_order_with_totals, store: store, seller: seller) }

  path '/api/v3/seller/exports' do
    post 'Create an export' do
      tags 'Exports'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Queues a CSV of this seller's own records.

        Only datasets that can be narrowed to a single seller are offered, so
        an export can never contain another seller's rows however it is
        filtered. The seller and the store come from the request context
        whatever the payload says.

        Generation runs in the background: poll `GET /api/v3/seller/exports/{id}`
        until `done` is true, then fetch `download_url`.
      DESC

      seller_sdk_example 'exports/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '201', 'export queued' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { type: 'orders' } }

        schema '$ref' => '#/components/schemas/Export'

        run_test! do |response|
          expect(JSON.parse(response.body)['type']).to eq('orders')
        end
      end

      response '422', 'type cannot be scoped to one seller' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { type: 'customers' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/exports/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Export ID'

    get 'Get an export' do
      tags 'Exports'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Reads one of this seller's exports. Poll this until `done` is true,
        then fetch `download_url`.
      DESC

      seller_sdk_example 'exports/get'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'export found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:export) { create(:order_export, store: store, seller: seller, user: seller_user) }
        let(:id) { export.prefixed_id }

        schema '$ref' => '#/components/schemas/Export'

        run_test!
      end

      response '404', "another seller's export" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) do
          create(:order_export, store: store, seller: create(:seller, :approved, store: store)).
            prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/exports/{id}/download' do
    parameter name: :id, in: :path, type: :string, description: 'Export ID'

    get 'Download an export' do
      tags 'Exports'
      produces 'text/csv'
      security [bearer_auth: []]
      description <<~DESC
        Streams the finished CSV.

        The bytes are served by this endpoint rather than through a redirect,
        so the seller's own session authorizes every download.
      DESC

      seller_sdk_example 'exports/download'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '422', 'export is still being written' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:export) { create(:order_export, store: store, seller: seller, user: seller_user) }
        let(:id) { export.prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '404', "another seller's export" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) do
          create(:order_export, store: store, seller: create(:seller, :approved, store: store)).
            prefixed_id
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
