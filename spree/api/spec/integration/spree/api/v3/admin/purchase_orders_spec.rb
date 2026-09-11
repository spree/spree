# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Purchase Orders API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:supplier) { create(:supplier, store: store, name: 'Acme Wholesale') }
  let!(:destination) { create(:stock_location, store: store, name: 'Brooklyn') }
  let!(:variant) { create(:variant) }
  let!(:order_record) do
    Spree::PurchaseOrders::Create.call(
      store: store, supplier: supplier, destination_location: destination,
      expected_at: '2026-10-01',
      items: [{ variant: variant, quantity_ordered: 100, unit_cost: 12.5 }]
    ).value
  end
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/purchase_orders' do
    get 'List purchase orders' do
      tags 'Purchase Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Stock bought from suppliers. A purchase order carries what a purchase
        has and a stock transfer does not: a supplier, a unit cost per line and
        an expected arrival date.

        Ordered units never count toward availability. Nothing here changes
        `count_on_hand` until `receive` runs, because a merchant who has
        ordered stock does not have it.

        Statuses are `draft`, `ordered`, `partially_received`, `received`, `over_received` and
        `canceled`. Each move between them is its own endpoint, not a `PATCH`
        that writes `status`.

        Filter with Ransack predicates such as `q[status_eq]`,
        `q[supplier_id_eq]` or `q[expected_at_lteq]`. Expand `items`,
        `supplier` and `destination_location`.
      DESC
      admin_scope :read, :purchasing

      admin_sdk_example 'purchase-orders/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      parameter name: :'q[status_eq]', in: :query, type: :string, required: false,
                description: "Filter by status ('draft', 'ordered', 'partially_received', 'received', 'over_received', 'canceled')"
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed: items, supplier, destination_location'

      response '200', 'purchase orders found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        schema SwaggerSchemaHelpers.paginated('PurchaseOrder')

        run_test! do |response|
          data = JSON.parse(response.body)
          row = data['data'].find { |po| po['id'] == order_record.prefixed_id }
          expect(row['status']).to eq('draft')
          expect(row['quantity_ordered_total']).to eq(100)
          expect(row['subtotal']).to eq('1250.0')
        end
      end

      response '401', 'unauthorized' do
        let(:'x-spree-api-key') { 'invalid' }
        let(:Authorization) { 'Bearer invalid' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a purchase order' do
      tags 'Purchase Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Drafts an order. Nothing is on order and nothing touches availability
        until the order is marked as ordered and then received.

        `currency` defaults to the store's; set it for a foreign-currency
        order. `expected_at` is a calendar date (`yyyy-mm-dd`) — the day the
        supplier promised means the same day in every timezone.
      DESC
      admin_scope :write, :purchasing

      admin_sdk_example 'purchase-orders/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :purchase_order, in: :body, required: true, schema: {
        type: :object,
        properties: {
          supplier_id: { type: :string, example: 'sup_1234567890' },
          destination_location_id: { type: :string, example: 'sloc_1234567890' },
          currency: { type: :string, nullable: true, example: 'USD' },
          expected_at: { type: :string, format: :date, nullable: true, example: '2026-10-01' },
          reference: { type: :string, nullable: true, description: "The supplier's own order number" },
          notes: { type: :string, nullable: true },
          items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                variant_id: { type: :string, example: 'variant_1234567890' },
                quantity_ordered: { type: :integer, example: 100 },
                unit_cost: { type: :string, example: '12.50' }
              },
              required: %w[variant_id quantity_ordered]
            }
          },
          metadata: { type: :object, nullable: true }
        },
        required: %w[supplier_id destination_location_id]
      }

      response '201', 'purchase order created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:purchase_order) do
          {
            supplier_id: supplier.prefixed_id,
            destination_location_id: destination.prefixed_id,
            expected_at: '2026-10-01',
            reference: 'SUP-8891',
            items: [{ variant_id: variant.prefixed_id, quantity_ordered: 100, unit_cost: '12.50' }]
          }
        end

        schema '$ref' => '#/components/schemas/PurchaseOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('draft')
          expect(data['number']).to start_with('PO')
          expect(destination.stock_level(variant.id)&.count_on_hand.to_i).to eq(0)
        end
      end

      response '404', 'supplier belongs to another store' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:purchase_order) do
          {
            supplier_id: create(:supplier, store: create(:store)).prefixed_id,
            destination_location_id: destination.prefixed_id,
            items: [{ variant_id: variant.prefixed_id, quantity_ordered: 1, unit_cost: '1.00' }]
          }
        end

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/purchase_orders/{id}' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Purchase order ID'

    get 'Get a purchase order' do
      tags 'Purchase Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :purchasing

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to embed: items, supplier, destination_location'

      response '200', 'purchase order found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { order_record.prefixed_id }
        let(:expand) { 'items,supplier' }

        schema '$ref' => '#/components/schemas/PurchaseOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['items'].first['unit_cost']).to eq('12.5')
          expect(data['supplier']['name']).to eq('Acme Wholesale')
        end
      end

      response '404', 'purchase order not found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { 'po_nonexistent' }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/purchase_orders/{id}/mark_ordered' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Purchase order ID'

    patch 'Place the order with the supplier' do
      tags 'Purchase Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Moves a `draft` to `ordered`: the lines are frozen and `ordered_at` is
        stamped. Availability is still untouched — ordered stock is not stock
        the merchant has.
      DESC
      admin_scope :write, :purchasing

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'purchase order placed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { order_record.prefixed_id }

        schema '$ref' => '#/components/schemas/PurchaseOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('ordered')
          expect(data['ordered_at']).to be_present
        end
      end
    end
  end

  path '/api/v3/admin/purchase_orders/{purchase_order_id}/stock_receipts' do
    parameter name: :purchase_order_id, in: :path, type: :string, required: true, description: 'Purchase order ID'

    get 'List the deliveries booked against an order' do
      tags 'Purchase Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Each delivery the dock counted in, newest first — with its packing-slip reference and what it accepted and refused.'
      admin_scope :read, :purchasing

      admin_sdk_example 'purchase-orders/stock-receipts/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'deliveries found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:purchase_order_id) { order_record.prefixed_id }

        before do
          Spree::PurchaseOrders::MarkOrdered.call(purchase_order: order_record)
          Spree::PurchaseOrders::Receive.call(purchase_order: order_record.reload,
                                              items: [{ item: order_record.items.first, quantity_accepted: 60 }],
                                              reference: 'DN-4471')
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data'].sole['reference']).to eq('DN-4471')
          expect(data['data'].sole['quantity_accepted_total']).to eq(60)
        end
      end
    end

    post 'Book in a delivery' do
      tags 'Purchase Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        The moment purchased goods first count toward availability. Records
        one delivery as a stock receipt: what this delivery brought, per line,
        not a running total — a second delivery adds to the first.

        `quantity_accepted` reaches the shelf; `quantity_rejected` is refused
        and recorded with a `rejection_reason` (`damaged`, `wrong_item`,
        `expired` or `other`), never stocked. Omit `items` to book in
        everything still outstanding, intact.

        Each `received` stock movement carries the line's `unit_cost` and
        names the receipt, so a delivery can be reconciled against the ledger.

        The order stays `partially_received` while any line is still owed,
        settles in `received` once every line has what it expected, and in
        `over_received` once any line has more.
      DESC
      admin_scope :write, :purchasing

      admin_sdk_example 'purchase-orders/stock-receipts/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :receipt, in: :body, required: false, schema: {
        type: :object,
        properties: {
          reference: { type: :string, nullable: true, example: 'DN-4471', description: "The supplier's delivery note or packing slip" },
          received_at: { type: :string, format: 'date-time', nullable: true, description: 'Defaults to now' },
          notes: { type: :string, nullable: true },
          items: {
            type: :array,
            items: {
              type: :object,
              properties: {
                id: { type: :string, example: 'poi_1234567890' },
                quantity_accepted: { type: :integer, example: 58 },
                quantity_rejected: { type: :integer, example: 2 },
                rejection_reason: { type: :string, nullable: true, example: 'damaged' },
                notes: { type: :string, nullable: true }
              },
              required: %w[id]
            }
          }
        }
      }

      response '201', 'delivery booked in' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:purchase_order_id) { order_record.prefixed_id }
        let(:receipt) do
          { reference: 'DN-4471',
            items: [{ id: order_record.items.first.prefixed_id, quantity_accepted: 58, quantity_rejected: 2,
                      rejection_reason: 'damaged' }] }
        end

        before { Spree::PurchaseOrders::MarkOrdered.call(purchase_order: order_record) }

        schema '$ref' => '#/components/schemas/StockReceipt'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['reference']).to eq('DN-4471')
          expect(data['quantity_accepted_total']).to eq(58)
          expect(data['quantity_rejected_total']).to eq(2)
          expect(order_record.reload).to be_partially_received
          expect(destination.stock_level(variant.id).reload.count_on_hand).to eq(58)
        end
      end

      response '422', 'order has not been placed yet' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:purchase_order_id) { order_record.prefixed_id }
        let(:receipt) { {} }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/purchase_orders/{id}/mark_draft' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Purchase order ID'

    patch 'Take an order back to draft' do
      tags 'Purchase Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Reopens a placed order for editing. Only while no delivery has been booked against it; `ordered_at` is cleared.'
      admin_scope :write, :purchasing

      admin_sdk_example 'purchase-orders/mark-draft'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'

      response '200', 'order back in draft' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { order_record.prefixed_id }

        before { Spree::PurchaseOrders::MarkOrdered.call(purchase_order: order_record) }

        schema '$ref' => '#/components/schemas/PurchaseOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('draft')
          expect(data['ordered_at']).to be_nil
        end
      end
    end
  end

  path '/api/v3/admin/purchase_orders/{id}/close' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Purchase order ID'

    patch 'Close an order short' do
      tags 'Purchase Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Ends a partially received order whose balance the supplier will not
        deliver. Nothing moves: what arrived stays on the shelf, the
        outstanding count stays on each line, and the order settles in
        `received` with `closed_short_at` and the `reason` recorded.
      DESC
      admin_scope :write, :purchasing

      admin_sdk_example 'purchase-orders/close'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :closure, in: :body, required: false, schema: {
        type: :object,
        properties: { reason: { type: :string, nullable: true, example: 'Supplier out of stock' } }
      }

      response '200', 'order closed short' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { order_record.prefixed_id }
        let(:closure) { { reason: 'Supplier out of stock' } }

        before do
          Spree::PurchaseOrders::MarkOrdered.call(purchase_order: order_record)
          Spree::PurchaseOrders::Receive.call(purchase_order: order_record.reload,
                                              items: [{ item: order_record.items.first, quantity_accepted: 60 }])
        end

        schema '$ref' => '#/components/schemas/PurchaseOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('received')
          expect(data['closed_short']).to be(true)
          expect(data['close_reason']).to eq('Supplier out of stock')
        end
      end
    end
  end

  path '/api/v3/admin/purchase_orders/{id}/cancel' do
    parameter name: :id, in: :path, type: :string, required: true, description: 'Purchase order ID'

    patch 'Cancel a purchase order' do
      tags 'Purchase Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Closes what is still outstanding. Nothing is unwound: a purchase order
        never moved stock until units were received, and units already received
        stay on the shelf because the merchant has them.

        A `reason` is appended to the order's notes.
      DESC
      admin_scope :write, :purchasing

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :cancellation, in: :body, required: false, schema: {
        type: :object,
        properties: { reason: { type: :string, example: 'Supplier went under' } }
      }

      response '200', 'purchase order cancelled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:id) { order_record.prefixed_id }
        let(:cancellation) { { reason: 'Supplier went under' } }

        schema '$ref' => '#/components/schemas/PurchaseOrder'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('canceled')
        end
      end
    end
  end
end
