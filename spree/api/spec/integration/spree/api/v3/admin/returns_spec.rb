# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Returns API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:record) { create(:return, order: create(:shipped_order, store: store)) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order) { record.order }
  let(:order_id) { order.prefixed_id }

  path '/api/v3/admin/returns' do
    get 'List returns' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Every return in the store, across all orders.'
      admin_scope :read, :orders

      admin_sdk_example 'returns/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'returns listed' do
        schema SwaggerSchemaHelpers.paginated('Return')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to include(record.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/returns' do
    get 'List order returns' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The returns opened on one order.'
      admin_scope :read, :orders

      admin_sdk_example 'order-returns/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'returns listed' do
        let(:order_id) { record.order.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Return')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to include(record.prefixed_id)
        end
      end
    end

    post 'Create a return' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Opens a return on a completed order for fulfilled units the customer is sending back.'
      admin_scope :write, :orders

      admin_sdk_example 'order-returns/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      request_body_for

      response '201', 'return opened' do
        let(:order) { create(:shipped_order, store: store) }
        let(:body) do
          { memo: 'Too small', items: [{ fulfillment_item_id: order.fulfillment_items.first.prefixed_id, quantity: 1 }] }
        end

        schema '$ref' => '#/components/schemas/Return'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('requested')
          expect(data['memo']).to eq('Too small')
        end
      end

      response '422', 'more returned than was fulfilled' do
        let(:order) { create(:shipped_order, store: store) }
        let(:body) { { items: [{ fulfillment_item_id: order.fulfillment_items.first.prefixed_id, quantity: 99 }] } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/returns/{id}' do
    patch 'Update a return' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Edits the warehouse, reason, memo or metadata of a return. Its status moves only through the approve, receive, refund and cancel actions.'
      admin_scope :write, :orders

      admin_sdk_example 'order-returns/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Return prefixed ID'
      request_body_for

      response '200', 'return updated' do
        let(:id) { record.prefixed_id }
        let(:reason) { create(:return_reason, store: store) }
        let(:body) { { memo: 'Customer shipped it back with a tracking number', reason_id: reason.prefixed_id } }

        schema '$ref' => '#/components/schemas/Return'

        run_test! do |response|
          expect(JSON.parse(response.body)['memo']).to eq('Customer shipped it back with a tracking number')
          expect(record.reload.reason).to eq(reason)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/returns/{id}/receive' do
    patch 'Receive a return' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Records what arrived on an approved return. Omit `items` to receive everything as requested and resellable; send rows for a partial or damaged receipt.'
      admin_scope :write, :orders

      admin_sdk_example 'order-returns/receive'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Return prefixed ID'
      request_body_for(required: false)

      response '200', 'return received' do
        let!(:record) { create(:approved_return, order: create(:shipped_order, store: store)) }
        let(:id) { record.prefixed_id }
        let(:body) do
          { items: [{ return_line_item_id: record.return_line_items.first.prefixed_id, quantity: 1, resellable: false }] }
        end

        schema '$ref' => '#/components/schemas/Return'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('received')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/returns/{id}/refund' do
    patch 'Refund a return' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Pays the customer back for a received return, to store credit or through the original payment.'
      admin_scope :write, :orders

      admin_sdk_example 'order-returns/refund'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Return prefixed ID'
      request_body_for(required: false)

      response '200', 'return refunded' do
        let!(:record) { create(:received_return, order: create(:shipped_order, store: store)) }
        let(:id) { record.prefixed_id }
        let(:body) { { refund_method: 'store_credit' } }

        schema '$ref' => '#/components/schemas/Return'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('refunded')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/returns/{id}/cancel' do
    patch 'Cancel a return' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws a return whose goods have not been received.'
      admin_scope :write, :orders

      admin_sdk_example 'order-returns/cancel'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Return prefixed ID'
      request_body_for(required: false)

      response '200', 'return canceled' do
        let(:id) { record.prefixed_id }
        let(:body) { { reason: 'Customer changed their mind' } }

        schema '$ref' => '#/components/schemas/Return'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/returns/{return_id}/labels' do
    get 'List return labels' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The shipping labels issued for sending one return back to the store.'
      admin_scope :read, :orders

      admin_sdk_example 'order-returns/labels-list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :return_id, in: :path, type: :string, required: true, description: 'Return prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'labels listed' do
        let!(:label) { create(:shipping_label, owner: record, store: store) }
        let(:order_id) { record.order.prefixed_id }
        let(:return_id) { record.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('ShippingLabel')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to include(label.prefixed_id)
        end
      end
    end
  end
end
