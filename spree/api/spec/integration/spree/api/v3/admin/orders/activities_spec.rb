# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Activities API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:completed_order_with_totals, store: store) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order_id) { order.prefixed_id }

  path '/api/v3/admin/orders/{order_id}/activities' do
    get 'List order activities' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Lists the order’s timeline, newest first: its placement, payments, refunds, shipments, changes, returns, ' \
                  'exchanges and claims, and the comments staff left on it. Recorded for orders placed since Spree 6.1.'
      admin_scope :read, :orders

      admin_sdk_example 'order-activities/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :expand, in: :query, type: :string, required: false,
                description: 'Comma-separated associations to expand (e.g., actor, order_change.actions.variant). ' \
                             'Use dot notation for nested expand (max 4 levels).'
      filter_parameters_for

      response '200', 'order activities listed' do
        let(:expand) { 'actor' }

        before do
          create(:order_activity, order: order, kind: 'order.placed', category: 'order', body: nil,
                                  details: { 'total' => '110.00', 'currency' => 'USD' }, created_at: 1.hour.ago)
          create(:order_activity, order: order, actor: admin_user)
        end

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.pluck('kind')).to eq(%w[comment order.placed])
          expect(data.first['actor']).to include('id' => admin_user.prefixed_id, 'type' => 'admin_user')
        end
      end
    end

    post 'Comment on an order' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Adds a staff comment to the order’s timeline. Comments can be deleted by their author but not edited.'
      admin_scope :write, :orders

      admin_sdk_example 'order-activities/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      request_body_for

      response '201', 'comment added' do
        let(:body) { { body: 'Customer asked to hold the parcel until Monday.' } }

        schema '$ref' => '#/components/schemas/OrderActivity'

        run_test! do |response|
          activity = JSON.parse(response.body)
          expect(activity).to include('kind' => 'comment', 'category' => 'comments', 'actor_id' => admin_user.prefixed_id)
        end
      end

      response '422', 'the comment is empty' do
        let(:body) { { body: '' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/activities/{id}' do
    delete 'Delete a comment' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Deletes a comment its author wrote. Every other entry records something that happened and cannot be deleted.'
      admin_scope :write, :orders

      admin_sdk_example 'order-activities/delete'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Order activity prefixed ID'

      response '204', 'comment deleted' do
        let(:id) { create(:order_activity, order: order, actor: admin_user).prefixed_id }

        run_test!
      end

      response '403', 'a comment someone else wrote' do
        let(:id) { create(:order_activity, order: order, actor: create(:admin_user)).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end

      response '422', 'not a comment' do
        let(:id) { create(:order_activity, order: order, kind: 'order.placed', category: 'order', body: nil).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end
end
