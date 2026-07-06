# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Fulfillments API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_ready_to_ship, store: store) }
  let!(:shipment) { order.shipments.first }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/fulfillments' do
    let(:order_id) { order.prefixed_id }

    get 'List fulfillments' do
      tags 'Fulfillments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all shipments for an order.'
      admin_scope :read, :fulfillments

      admin_sdk_example 'order-fulfillments/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., inventory_units, stock_location, shipping_rates). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., number,status,tracking,cost). id is always included.'

      response '200', 'fulfillments found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].length).to eq(1)
        end
      end
    end

    post 'Create a fulfillment' do
      tags 'Fulfillments'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Manually creates a fulfillment on a completed order, bypassing order routing — for example to mirror a shipment handled by an external carrier or 3PL. ' \
                  'Moves the requested line item quantities out of their current fulfillments; when `items` is omitted, every not-yet-shipped unit is moved. ' \
                  "Pass `status: 'shipped'` to register an already-shipped fulfillment (fires shipped webhooks and freezes cost/carrier). " \
                  'When `delivery_method_id` is omitted, the fulfillment inherits the delivery method and cost of the source fulfillment(s) it fully drains — keeping the order total unchanged; ' \
                  'partially drained splits get no carrier when shipped, and pending fulfillments are otherwise (re)priced by the standard rate engine, which selects the lowest-cost available rate. ' \
                  'Pass `cost` to set an explicit shipping cost instead (e.g. the 3PL price) — note this changes the order total and payment state, ' \
                  "and is guaranteed to persist only with `status: 'shipped'` (pending fulfillments are re-priced by the rate engine)."
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-fulfillments/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[stock_location_id],
        properties: {
          stock_location_id: { type: :string, description: 'Stock location the fulfillment ships from' },
          tracking: { type: :string, example: 'INPOST-12345', description: 'Carrier tracking number, or a full https:// tracking link — a full URL is served back as tracking_url unchanged instead of being templated into the delivery method tracking URL' },
          delivery_method_id: { type: :string, description: 'Delivery method (carrier) to attach as the selected rate. Defaults to the delivery method of the fully drained source fulfillment(s)' },
          cost: { type: :string, example: '7.42', description: "Explicit shipping cost. Defaults to the summed cost of the fully drained source fulfillment(s), which keeps the order total unchanged; an explicit cost changes the order total and payment state. Guaranteed to persist only with status: 'shipped' — pending fulfillments are re-priced by the rate engine" },
          status: { type: :string, enum: %w[shipped], description: "Pass 'shipped' to register the fulfillment as already shipped" },
          items: {
            type: :array,
            description: 'Line item quantities to fulfill. Omit to fulfill every not-yet-shipped unit.',
            items: {
              type: :object,
              required: %w[item_id quantity],
              properties: {
                item_id: { type: :string, description: 'Line item ID' },
                quantity: { type: :integer, example: 1 }
              }
            }
          },
          metadata: { type: :object, additionalProperties: true }
        }
      }

      response '201', 'fulfillment created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) do
          {
            stock_location_id: shipment.stock_location.prefixed_id,
            tracking: 'INPOST-12345',
            status: 'shipped'
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to start_with('ful_')
          expect(data['tracking']).to eq('INPOST-12345')
          expect(data['status']).to eq('shipped')
        end
      end

      response '422', 'order not completed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:draft_order) { create(:order_with_line_items, store: store) }
        let(:order_id) { draft_order.prefixed_id }
        let(:body) { { stock_location_id: draft_order.shipments.first.stock_location.prefixed_id } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['message']).to eq(Spree.t('fulfillments.errors.order_not_completed'))
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { shipment.prefixed_id }

    get 'Show a shipment' do
      tags 'Fulfillments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns details of a specific shipment.'
      admin_scope :read, :fulfillments

      admin_sdk_example 'order-fulfillments/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., inventory_units, stock_location, shipping_rates). Use dot notation for nested expand (max 4 levels).'
      parameter name: :fields, in: :query, type: :string, required: false,
                description: 'Comma-separated list of fields to include (e.g., number,status,tracking,cost). id is always included.'

      response '200', 'shipment found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(shipment.prefixed_id)
          expect(data['number']).to be_present
        end
      end
    end

    patch 'Update a shipment' do
      tags 'Fulfillments'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Updates a fulfillment (tracking, delivery rate).'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-fulfillments/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          tracking: { type: :string, example: '1Z999AA10123456784', description: 'Carrier tracking number, or a full https:// tracking link served back as tracking_url unchanged' },
          selected_delivery_rate_id: { type: :string, description: 'Delivery rate ID (dr_...) to select' }
        }
      }

      response '200', 'shipment updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:body) { { tracking: '1Z999AA10123456784' } }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['tracking']).to eq('1Z999AA10123456784')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/fulfill' do
    patch 'Fulfill a fulfillment' do
      tags 'Fulfillments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Marks a fulfillment as fulfilled.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-fulfillments/fulfill'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'

      response '200', 'fulfillment fulfilled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }

        before do
          shipment.ready! if shipment.can_ready?
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('shipped')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/cancel' do
    patch 'Cancel a fulfillment' do
      tags 'Fulfillments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Cancels a fulfillment.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-fulfillments/cancel'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'

      response '200', 'fulfillment canceled' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('canceled')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/resume' do
    patch 'Resume a fulfillment' do
      tags 'Fulfillments'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Resumes a canceled fulfillment.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-fulfillments/resume'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'

      response '200', 'fulfillment resumed' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }

        before do
          shipment.cancel!
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(%w[pending ready]).to include(data['status'])
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fulfillments/{id}/split' do
    patch 'Split a fulfillment' do
      tags 'Fulfillments'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Transfers items from this shipment to a new shipment at a different stock location.'
      admin_scope :write, :fulfillments

      admin_sdk_example 'order-fulfillments/split'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'
      parameter name: :id, in: :path, type: :string, required: true,
                description: 'Fulfillment ID'
      parameter name: :body, in: :body, schema: {
        type: :object,
        required: %w[variant_id quantity],
        properties: {
          variant_id: { type: :string, description: 'Variant ID' },
          quantity: { type: :integer, example: 1 },
          stock_location_id: { type: :string, description: 'Target stock location ID' }
        }
      }

      response '200', 'fulfillment split' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:order_id) { order.prefixed_id }
        let(:id) { shipment.prefixed_id }
        let(:variant) { shipment.inventory_units.first.variant }
        let(:stock_location) { create(:stock_location, name: 'Warehouse 2') }
        let(:body) { { variant_id: variant.prefixed_id, quantity: 1, stock_location_id: stock_location.prefixed_id } }

        before do
          stock_location.stock_items.find_or_create_by(variant: variant).set_count_on_hand(10)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
        end
      end
    end
  end
end
