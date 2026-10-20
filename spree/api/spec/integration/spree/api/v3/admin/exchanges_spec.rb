# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Exchanges API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:record) { create(:exchange, order: create(:shipped_order, store: store)) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order) { record.order }
  let(:order_id) { order.prefixed_id }

  path '/api/v3/admin/exchanges' do
    get 'List exchanges' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Every exchange in the store, across all orders.'
      admin_scope :read, :orders

      admin_sdk_example 'exchanges/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'exchanges listed' do
        schema SwaggerSchemaHelpers.paginated('Exchange')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to include(record.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/exchanges' do
    get 'List order exchanges' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The exchanges opened on one order.'
      admin_scope :read, :orders

      admin_sdk_example 'order-exchanges/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'exchanges listed' do
        let(:order_id) { record.order.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Exchange')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to include(record.prefixed_id)
        end
      end
    end

    post 'Create an exchange' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Opens an exchange on a completed order: items coming back, and the variant that goes out in place of each.'
      admin_scope :write, :orders

      admin_sdk_example 'order-exchanges/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      request_body_for

      response '201', 'exchange opened' do
        let(:order) { create(:shipped_order, store: store) }
        let(:fulfillment_item) { order.fulfillment_items.first }
        let(:replacement) { create(:variant, product: fulfillment_item.variant.product) }
        let(:body) do
          {
            memo: 'Wrong size',
            items: [{ fulfillment_item_id: fulfillment_item.prefixed_id, new_variant_id: replacement.prefixed_id, quantity: 1 }]
          }
        end

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('requested')
          expect(data['memo']).to eq('Wrong size')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/exchanges/{id}' do
    patch 'Update an exchange' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Edits the warehouse, reason, memo or metadata of an exchange. Its status moves only through the approve, receive, fulfill and cancel actions.'
      admin_scope :write, :orders

      admin_sdk_example 'order-exchanges/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Exchange prefixed ID'
      request_body_for

      response '200', 'exchange updated' do
        let(:id) { record.prefixed_id }
        let(:reason) { create(:return_reason, store: store) }
        let(:body) { { memo: 'Customer wants a larger size', reason_id: reason.prefixed_id } }

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)['memo']).to eq('Customer wants a larger size')
          expect(record.reload.reason).to eq(reason)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/exchanges/{id}/receive' do
    patch 'Receive an exchange' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Records the goods that came back on an approved exchange. Omit `items` to receive everything as requested and resellable.'
      admin_scope :write, :orders

      admin_sdk_example 'order-exchanges/receive'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Exchange prefixed ID'
      request_body_for(required: false)

      response '200', 'exchange received' do
        let!(:record) { create(:approved_exchange, order: create(:shipped_order, store: store)) }
        let(:id) { record.prefixed_id }
        let(:body) do
          { items: [{ exchange_line_item_id: record.exchange_line_items.first.prefixed_id, quantity: 1, resellable: false }] }
        end

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('received')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/exchanges/{id}/fulfill' do
    patch 'Fulfill an exchange' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Ships the replacements for a received exchange and settles any price difference.'
      admin_scope :write, :orders

      admin_sdk_example 'order-exchanges/fulfill'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Exchange prefixed ID'
      request_body_for(required: false)

      response '200', 'exchange fulfilled' do
        let!(:record) { create(:received_exchange, order: create(:shipped_order, store: store)) }
        let(:id) { record.prefixed_id }
        let(:body) { { refund_method: 'store_credit' } }

        before do
          record.exchange_line_items.each { |line| line.new_variant.stock_levels.first&.set_count_on_hand(10) }
        end

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('fulfilled')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/exchanges/{id}/cancel' do
    patch 'Cancel an exchange' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws an exchange whose goods have not been received.'
      admin_scope :write, :orders

      admin_sdk_example 'order-exchanges/cancel'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Exchange prefixed ID'
      request_body_for(required: false)

      response '200', 'exchange canceled' do
        let(:id) { record.prefixed_id }
        let(:body) { { reason: 'Customer kept the original' } }

        schema '$ref' => '#/components/schemas/Exchange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
        end
      end
    end
  end
end
