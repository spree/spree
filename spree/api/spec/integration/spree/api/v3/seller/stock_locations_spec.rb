# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Stock Locations API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # The seeded role rather than the shared context's products-only one — stock
  # locations are gated on the `stock` permission, which that role omits.
  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end

  let!(:stock_location) { create(:stock_location, store: store, seller: seller) }

  path '/api/v3/seller/stock_locations' do
    get 'List stock locations' do
      tags 'Stock Locations'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Where this seller keeps stock, and so where their returns are sent.

        Rooted in the acting seller, so the marketplace operator's own warehouses
        never appear here.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      parameter name: :sort, in: :query, type: :string, required: false, description: 'Sort field; prefix with `-` for descending'

      response '200', 'stock locations listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/StockLocation' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(stock_location.prefixed_id)
        end
      end
    end

    post 'Create a stock location' do
      tags 'Stock Locations'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Adds a place this seller ships from.

        The seller and the store come from the request context whatever the
        payload says.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Main warehouse' },
          company: { type: :string, nullable: true },
          address1: { type: :string, nullable: true, example: '1 Kiln Lane' },
          address2: { type: :string, nullable: true },
          city: { type: :string, nullable: true, example: 'Portland' },
          zipcode: { type: :string, nullable: true, example: '97205' },
          country_code: { type: :string, nullable: true, example: 'US' },
          state_code: { type: :string, nullable: true, example: 'OR' },
          state_name: { type: :string, nullable: true },
          phone: { type: :string, nullable: true },
          active: { type: :boolean, description: 'Set `false` to retire a location — there is no delete' },
          default: { type: :boolean },
          kind: { type: :string, example: 'warehouse' }
        },
        required: %w[name]
      }

      response '201', 'stock location created' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: 'Main warehouse', city: 'Portland', country_code: 'US' } }

        schema '$ref' => '#/components/schemas/StockLocation'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Main warehouse')
        end
      end

      response '422', 'validation failed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:body) { { name: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/stock_locations/{id}' do
    parameter name: :id, in: :path, type: :string, description: 'Stock location ID'

    get 'Get a stock location' do
      tags 'Stock Locations'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        A stock location the acting seller owns. An id belonging to another
        seller — or to the marketplace operator — answers `404`.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'stock location returned' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { stock_location.prefixed_id }

        schema '$ref' => '#/components/schemas/StockLocation'

        run_test!
      end

      response '404', "another seller's stock location" do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:other_seller) { create(:seller, :approved, store: store) }
        let(:id) { create(:stock_location, store: store, seller: other_seller).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    patch 'Update a stock location' do
      tags 'Stock Locations'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Edits a stock location the acting seller owns.

        There is no delete: a location holds stock levels and is named on
        historical fulfillments, so a seller retires one by setting `active` to
        `false`.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Main warehouse' },
          address1: { type: :string, nullable: true },
          city: { type: :string, nullable: true },
          zipcode: { type: :string, nullable: true },
          country_code: { type: :string, nullable: true },
          state_code: { type: :string, nullable: true },
          phone: { type: :string, nullable: true },
          active: { type: :boolean },
          default: { type: :boolean }
        }
      }

      response '200', 'stock location updated' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { stock_location.prefixed_id }
        let(:body) { { name: 'Kiln Lane warehouse' } }

        schema '$ref' => '#/components/schemas/StockLocation'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Kiln Lane warehouse')
        end
      end
    end
  end
end
