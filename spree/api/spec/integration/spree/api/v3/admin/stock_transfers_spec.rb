# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Stock Transfers API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:source) { create(:stock_location, store: store, name: 'Warehouse') }
  let!(:destination) { create(:stock_location, store: store, name: 'Brooklyn shop') }
  let!(:variant) { create(:variant) }
  let!(:transfer_record) do
    Spree::StockTransfers::Create.call(
      store: store, source_location: source, destination_location: destination,
      reference: 'Weekly restock',
      items: [{ variant: variant, quantity_shipped: 10 }]
    ).value
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  before { source.restock(variant, 50) }

  path '/api/v3/admin/stock_transfers' do
    get 'List stock transfers' do
      tags 'Stock Transfers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Stock moving between two of the merchant's own warehouses.

        A transfer is a trip, not an instant. Units leave the source when the
        transfer is marked in transit and land at the destination when somebody
        counts them in — in between they are in flight, gone from one shelf and
        not yet on the other.

        Statuses are `draft`, `ready_to_ship`, `in_transit`,
        `partially_received`, `received` and `canceled`. Each move between them
        is its own endpoint, not a `PATCH` that writes `status`.

        Receiving from a supplier is a purchase order, not a transfer with a
        missing source.

        Filter with Ransack predicates such as `q[status_eq]`,
        `q[source_location_id_eq]` or `q[number_or_reference_cont]`. Expand
        `items`, `source_location` and `destination_location`.
      DESC
      admin_scope :read, :stock

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[status_eq]', in: :query, type: :string, required: false,
                description: "Filter by status ('draft', 'ready_to_ship', 'in_transit', 'partially_received', 'received', 'canceled')"
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed: items, source_location, destination_location'

      response '200', 'stock transfers found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('StockTransfer')

        run_test! do |response|
          data = JSON.parse(response.body)
          row = data['data'].find { |transfer| transfer['id'] == transfer_record.prefixed_id }
          expect(row['status']).to eq('draft')
          expect(row['quantity_shipped_total']).to eq(10)
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a stock transfer' do
      tags 'Stock Transfers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Persists a draft — a packing list the merchant can still edit. Nothing
        moves until the transfer is marked in transit.

        A draft may legitimately open empty and gain lines as the merchant
        packs. Both warehouses are required and must belong to the same store.
      DESC
      admin_scope :write, :stock

      admin_sdk_example 'stock-transfers/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :stock_transfer, in: :body, required: true, schema: {
        type: :object,
        properties: {
          source_location_id: { type: :string, example: 'sloc_1234567890' },
          destination_location_id: { type: :string, example: 'sloc_0987654321' },
          reference: { type: :string, nullable: true, description: "The merchant's own label for the trip" },
          notes: { type: :string, nullable: true },
          items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                variant_id: { type: :string, example: 'variant_1234567890' },
                quantity_shipped: { type: :integer, example: 10 }
              },
              required: %w[variant_id quantity_shipped]
            }
          },
          metadata: { type: :object, nullable: true }
        },
        required: %w[source_location_id destination_location_id]
      }

      response '201', 'stock transfer created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:stock_transfer) do
          {
            source_location_id: source.prefixed_id,
            destination_location_id: destination.prefixed_id,
            reference: 'Weekly restock',
            items: [{ variant_id: variant.prefixed_id, quantity_shipped: 10 }]
          }
        end

        schema '$ref' => '#/components/schemas/StockTransfer'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('draft')
          expect(data['number']).to start_with('T')
          expect(source.stock_level(variant.id).reload.count_on_hand).to eq(50)
        end
      end

      response '404', 'warehouse belongs to another store' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:stock_transfer) do
          {
            source_location_id: source.prefixed_id,
            destination_location_id: create(:stock_location, store: create(:store)).prefixed_id,
            items: [{ variant_id: variant.prefixed_id, quantity_shipped: 1 }]
          }
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/stock_transfers/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Stock transfer ID'

    get 'Get a stock transfer' do
      tags 'Stock Transfers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :stock

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed: items, source_location, destination_location'

      response '200', 'stock transfer found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }
        let(:expand) { 'items,source_location,destination_location' }

        schema '$ref' => '#/components/schemas/StockTransfer'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['items'].first['quantity_shipped']).to eq(10)
          expect(data['source_location']['name']).to eq('Warehouse')
        end
      end

      response '404', 'stock transfer not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'st_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    delete 'Delete a stock transfer' do
      tags 'Stock Transfers'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Drafts only. Past `draft` the transfer describes a box that physically
        exists, so it is cancelled rather than deleted — a 422 says so.
      DESC
      admin_scope :write, :stock

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '204', 'stock transfer deleted' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }

        run_test!
      end
    end
  end

  path '/api/v3/admin/stock_transfers/{id}/mark_ready' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Stock transfer ID'

    patch 'Mark a transfer ready to ship' do
      tags 'Stock Transfers'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Freezes the lines so the warehouse and the merchant are looking at the
        same list. Nothing leaves the shelf yet.
      DESC
      admin_scope :write, :stock

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'transfer is ready to ship' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }

        schema '$ref' => '#/components/schemas/StockTransfer'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('ready_to_ship')
        end
      end
    end
  end

  path '/api/v3/admin/stock_transfers/{id}/mark_in_transit' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Stock transfer ID'

    patch 'Send a transfer' do
      tags 'Stock Transfers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The moment stock leaves the source warehouse: `shipped` movements are
        written against the source's levels and `shipped_at` is stamped. The
        destination is deliberately untouched — the units are in flight.

        Refused with a 422 when the source does not hold enough. Pass
        `force: true` to record the departure anyway: a merchant forcing it has
        decided the box left whatever the ledger claims.
      DESC
      admin_scope :write, :stock

      admin_sdk_example 'stock-transfers/mark-in-transit'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :departure, in: :body, required: false, schema: {
        type: :object,
        properties: {
          force: {
            type: :boolean,
            description: 'Ship even if it drives the source below zero'
          }
        }
      }

      response '200', 'transfer is in transit' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }
        let(:departure) { {} }

        schema '$ref' => '#/components/schemas/StockTransfer'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('in_transit')
          expect(data['shipped_at']).to be_present
          expect(source.stock_level(variant.id).reload.count_on_hand).to eq(40)
          expect(destination.stock_level(variant.id)&.count_on_hand.to_i).to eq(0)
        end
      end
    end
  end

  path '/api/v3/admin/stock_transfers/{id}/receive' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Stock transfer ID'

    patch 'Receive a transfer' do
      tags 'Stock Transfers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Records what the destination warehouse actually counted in.

        Partial receipt is the normal case, not an edge case: ten left, eight
        arrived, two were crushed in transit. `quantity_received` is the running
        total for the line, so a second delivery tops it up rather than
        starting over, and only the difference reaches the shelf. Omit `items`
        to receive every line in full.

        `discrepancy_reason` records why fewer arrived —
        `damaged_in_transit`, `lost_in_transit` or `undercount`.

        The transfer settles in `received` once every line is complete, and
        stays `partially_received` while any is still owed.
      DESC
      admin_scope :write, :stock

      admin_sdk_example 'stock-transfers/receive'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :receipt, in: :body, required: false, schema: {
        type: :object,
        properties: {
          items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :string, example: 'sti_1234567890' },
                quantity_received: { type: :integer, example: 8 },
                discrepancy_reason: { type: :string, nullable: true, example: 'damaged_in_transit' }
              },
              required: %w[id quantity_received]
            }
          }
        }
      }

      response '200', 'transfer received' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }
        let(:receipt) do
          {
            items: [
              {
                id: transfer_record.items.first.prefixed_id,
                quantity_received: 8,
                discrepancy_reason: 'damaged_in_transit'
              }
            ]
          }
        end

        before { Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer_record) }

        schema '$ref' => '#/components/schemas/StockTransfer'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('partially_received')
          expect(data['quantity_received_total']).to eq(8)
          expect(destination.stock_level(variant.id).reload.count_on_hand).to eq(8)
        end
      end

      response '422', 'transfer has not shipped yet' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }
        let(:receipt) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/stock_transfers/{id}/cancel' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Stock transfer ID'

    patch 'Cancel a stock transfer' do
      tags 'Stock Transfers'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Calls the trip off.

        Cancelling a draft or a packed transfer costs nothing — no stock has
        moved. Cancelling one already in transit needs `on_in_transit`, because
        the units are physically gone from the source: either they come back
        (`restock`, as if the transfer had never shipped) or they are written
        off as lost (`write_off`). There is no default — guessing would either
        invent stock or destroy it — so an in-flight cancellation without it is
        refused with a 422.
      DESC
      admin_scope :write, :stock

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :cancellation, in: :body, required: false, schema: {
        type: :object,
        properties: {
          on_in_transit: {
            type: :string,
            enum: %w[restock write_off],
            description: 'Required once the units have left the source'
          },
          reason: { type: :string, nullable: true, description: 'Recorded against the written-off lines' }
        }
      }

      response '200', 'transfer cancelled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }
        let(:cancellation) { { on_in_transit: 'restock' } }

        before { Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer_record) }

        schema '$ref' => '#/components/schemas/StockTransfer'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
          expect(source.stock_level(variant.id).reload.count_on_hand).to eq(50)
        end
      end

      response '422', 'in-transit cancellation needs a decision' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { transfer_record.prefixed_id }
        let(:cancellation) { {} }

        before { Spree::StockTransfers::MarkInTransit.call(stock_transfer: transfer_record) }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
