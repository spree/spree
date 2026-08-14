# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Stock Movements API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:stock_location) { create(:stock_location) }
  let!(:variant) { create(:variant) }
  let!(:stock_movement) { stock_location.adjust(variant, 5, reason: 'Cycle count') }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/stock_movements' do
    get 'List stock movements' do
      tags 'Stock Movements'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Returns the stock ledger, newest first. Every row says what happened to
        stock (`kind`) and carries a direct reference to what caused it, so a
        merchant can answer "why is this number what it is?" from the data.

        Kinds are `received` (goods arrived), `allocated` (stock promised to a
        placed order), `shipped` (promised stock left), `released` (a promise
        withdrawn) and `adjusted` (a manual correction, which always carries a
        `reason`).

        Movements are immutable — reversing one means writing its counterpart
        through the resource that caused it, which is why there is no create,
        update or delete here.

        Filter with Ransack predicates such as `q[kind_eq]`,
        `q[stock_level_id_eq]`, `q[order_id_eq]`, `q[fulfillment_id_eq]` or
        `q[created_at_gteq]`.

        `kind` is null on rows written before Spree 6.0 until
        `spree:migrate_stock_movements_to_typed_rows` has run.
      DESC
      admin_scope :read, :stock

      admin_sdk_example 'stock-movements/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[kind_eq]', in: :query, type: :string, required: false,
                description: "Filter by kind ('received', 'allocated', 'shipped', 'released', 'adjusted')"
      parameter name: :'q[stock_level_id_eq]', in: :query, type: :integer, required: false,
                description: 'Filter by stock level'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'stock movements found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('StockMovement')

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].map { |movement| movement['id'] }).to include(stock_movement.prefixed_id)
          expect(data['data'].first['kind']).to eq('adjusted')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/stock_movements/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Stock movement ID'

    get 'Get a stock movement' do
      tags 'Stock Movements'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns a single stock movement by prefixed ID.'
      admin_scope :read, :stock

      admin_sdk_example 'stock-movements/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include. id is always included.'

      response '200', 'stock movement found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { stock_movement.prefixed_id }

        schema '$ref' => '#/components/schemas/StockMovement'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(stock_movement.prefixed_id)
          expect(data['reason']).to eq('Cycle count')
        end
      end

      response '404', 'stock movement not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'sm_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
