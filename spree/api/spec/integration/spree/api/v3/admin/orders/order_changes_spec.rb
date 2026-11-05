# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Changes API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order_id) { order.prefixed_id }

  let(:requested_change) do
    Spree::OrderChanges::Apply.call(order: order, confirm: false,
                                    actions: [{ kind: 'update_item', line_item: line_item, quantity: 2 }]).value
  end

  path '/api/v3/admin/orders/{order_id}/order_changes' do
    get 'List order changes' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Lists every change made to a placed order: admin edits, and the restocks and replacement shipments ' \
                  'of its returns, exchanges and claims.'
      admin_scope :read, :orders

      admin_sdk_example 'order-changes/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      filter_parameters_for

      response '200', 'order changes listed' do
        before { requested_change }

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].pluck('id')).to eq([requested_change.prefixed_id])
        end
      end
    end

    post 'Create an order change' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Changes the line items of a placed order in one transaction. With `confirm: true` the change is applied at once; ' \
                  'otherwise it waits as `requested`. No money moves: the order shows any balance due or credit owed, ' \
                  'settled from its payments. Edit a draft order through the order itself instead.'
      admin_scope :write, :orders

      admin_sdk_example 'order-changes/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      request_body_for

      response '201', 'order change applied' do
        let(:body) { { confirm: true, actions: [{ kind: 'update_item', line_item_id: line_item.prefixed_id, quantity: 2 }] } }

        schema '$ref' => '#/components/schemas/OrderChange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('confirmed')
        end
      end

      response '422', 'the order is not placed' do
        let!(:order) { create(:order_with_line_items, store: store) }
        let(:body) { { confirm: true, actions: [{ kind: 'remove_item', line_item_id: line_item.prefixed_id }] } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/order_changes/preview' do
    post 'Preview an order change' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Answers what the order totals would be after a change, and how far the balance would move, without saving anything.'
      admin_scope :write, :orders

      admin_sdk_example 'order-changes/preview'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      request_body_for

      response '200', 'order change previewed' do
        let(:body) { { actions: [{ kind: 'update_item', line_item_id: line_item.prefixed_id, quantity: 3 }] } }

        schema '$ref' => '#/components/schemas/OrderChangePreview'

        run_test! do |response|
          expect(JSON.parse(response.body)['balance_delta'].to_d).to be_positive
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/order_changes/{id}/confirm' do
    patch 'Confirm an order change' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Applies a requested order change in one transaction.'
      admin_scope :write, :orders

      admin_sdk_example 'order-changes/confirm'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Order change prefixed ID'

      response '200', 'order change confirmed' do
        let(:id) { requested_change.prefixed_id }

        schema '$ref' => '#/components/schemas/OrderChange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('confirmed')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/order_changes/{id}/cancel' do
    patch 'Cancel an order change' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Discards an order change that has not been applied. The change is kept as a record of what was proposed.'
      admin_scope :write, :orders

      admin_sdk_example 'order-changes/cancel'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Order change prefixed ID'

      response '200', 'order change canceled' do
        let(:id) { requested_change.prefixed_id }

        schema '$ref' => '#/components/schemas/OrderChange'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
        end
      end
    end
  end
end
