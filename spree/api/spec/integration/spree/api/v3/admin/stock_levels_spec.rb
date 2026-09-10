# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Stock Levels API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:product) { create(:product, store: store) }
  let!(:variant) { create(:variant, product: product) }
  let!(:stock_location) { create(:stock_location, store: store) }

  path '/api/v3/admin/stock_levels' do
    get 'List stock levels' do
      tags 'Stock'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        One row per variant per stock location, carrying every figure the
        Inventory page shows: `count_on_hand` (on hand), `allocated_count`
        (committed to placed orders), `reserved_count` (held by checkouts in
        progress), `available_count` (on hand minus committed) and
        `incoming_count` (on its way on an open purchase order or a transfer
        in transit). The variant and location are named flat on the row
        (`variant_name`, `variant_sku`, `stock_location_name`, `thumbnail_url`)
        so a list needs no expansion.

        Filter with `q[stock_location_id_eq]`, `q[variant_id_eq]` or
        `q[variant_sku_or_variant_product_name_cont]`.
      DESC
      admin_scope :read, :stock

      admin_sdk_example 'stock-levels/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[stock_location_id_eq]', in: :query, type: :string, required: false,
                description: 'Only levels at this stock location'

      response '200', 'stock levels found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let!(:stock_level) do
          create(:stock_level, variant: variant, stock_location: stock_location, adjust_count_on_hand: false).tap do |level|
            level.update_columns(count_on_hand: 40, allocated_count: 3, reserved_count: 2, incoming_count: 20)
          end
        end

        schema SwaggerSchemaHelpers.paginated('StockLevel')

        run_test! do |response|
          row = JSON.parse(response.body)['data'].find { |level| level['id'] == stock_level.prefixed_id }
          expect(row).to include('available_count' => 37, 'reserved_count' => 2, 'incoming_count' => 20)
        end
      end
    end
  end

  path '/api/v3/admin/stock_levels/bulk_upsert' do
    post 'Bulk-upsert stock levels' do
      tags 'Stock'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Sets stock levels for many (variant, location) pairs at once — what a
        warehouse or ERP feed posts on a schedule.

        Each row names its variant and stock location by Spree id
        (`variant_id`, `stock_location_id`).

        A row carries either `count_on_hand` — the absolute level the external
        system reports — or `adjustment`, a relative change for feeds that
        report movements instead. Every change is written as a stock movement,
        so a merchant can still see why a figure moved.

        The response carries `stock_level_count`: how many rows moved a shelf.
      DESC
      admin_scope :write, :stock

      admin_sdk_example 'stock-levels/bulk-upsert'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[stock_levels],
        properties: {
          stock_levels: {
            type: :array,
            items: {
              type: :object,
              required: %w[variant_id stock_location_id],
              properties: {
                variant_id: { type: :string, example: 'variant_xY9' },
                stock_location_id: { type: :string, example: 'sloc_aBc' },
                count_on_hand: { type: :integer, nullable: true, example: 42 },
                adjustment: { type: :integer, nullable: true, example: -3 },
                backorderable: { type: :boolean, nullable: true }
              }
            }
          }
        }
      }

      response '200', 'stock levels updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            stock_levels: [
              {
                variant_id: variant.prefixed_id,
                stock_location_id: stock_location.prefixed_id,
                count_on_hand: 42
              }
            ]
          }
        end

        run_test! do |response|
          expect(JSON.parse(response.body)['stock_level_count']).to eq(1)
        end
      end

      response '422', 'row is missing a level' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          { stock_levels: [{ variant_id: variant.prefixed_id, stock_location_id: stock_location.prefixed_id }] }
        end

        run_test!
      end
    end
  end
end
