# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Claims API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:record) { create(:claim, order: create(:shipped_order, store: store)) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }
  let(:order) { record.order }
  let(:order_id) { order.prefixed_id }

  path '/api/v3/admin/claims' do
    get 'List claims' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Every damage or missing-item claim in the store, across all orders.'
      admin_scope :read, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'claims listed' do
        schema SwaggerSchemaHelpers.paginated('Claim')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to include(record.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/claims' do
    get 'List order claims' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The damage or missing-item claims opened on one order.'
      admin_scope :read, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'claims listed' do
        let(:order_id) { record.order.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('Claim')

        run_test! do |response|
          expect(JSON.parse(response.body)['data'].map { |row| row['id'] }).to include(record.prefixed_id)
        end
      end
    end

    post 'Create a claim' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Opens a damage or missing-item claim on a completed order. Each item says how it should be made right: money back, a replacement, or both.'
      admin_scope :write, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      request_body_for

      response '201', 'claim opened' do
        let(:order) { create(:shipped_order, store: store) }
        let(:body) do
          {
            memo: 'Arrived cracked',
            items: [{ line_item_id: order.line_items.first.prefixed_id, quantity: 1, description: 'Cracked screen', refund_amount: '10.00' }]
          }
        end

        schema '$ref' => '#/components/schemas/Claim'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('open')
          expect(data['memo']).to eq('Arrived cracked')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/claims/{id}' do
    patch 'Update a claim' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Edits the reason, memo or metadata of a claim. Its status moves only through the approve, resolve, deny and cancel actions.'
      admin_scope :write, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Claim prefixed ID'
      request_body_for

      response '200', 'claim updated' do
        let(:id) { record.prefixed_id }
        let(:reason) { create(:claim_reason, store: store) }
        let(:body) { { memo: 'Customer sent photos', reason_id: reason.prefixed_id } }

        schema '$ref' => '#/components/schemas/Claim'

        run_test! do |response|
          expect(JSON.parse(response.body)['memo']).to eq('Customer sent photos')
          expect(record.reload.reason).to eq(reason)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/claims/{id}/resolve' do
    patch 'Resolve a claim' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Settles an approved claim with money back, a replacement shipment, or both.'
      admin_scope :write, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Claim prefixed ID'
      request_body_for

      response '200', 'claim resolved' do
        let!(:record) { create(:approved_claim, order: create(:shipped_order, store: store)) }
        let(:id) { record.prefixed_id }
        let(:body) { { resolution: 'refund', refund_method: 'store_credit' } }

        schema '$ref' => '#/components/schemas/Claim'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['status']).to eq('resolved')
          expect(data['resolution']).to eq('refund')
        end
      end

      response '422', 'unknown resolution' do
        let!(:record) { create(:approved_claim, order: create(:shipped_order, store: store)) }
        let(:id) { record.prefixed_id }
        let(:body) { { resolution: 'apologize' } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/claims/{id}/deny' do
    patch 'Deny a claim' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Turns down an open claim, recording why for the customer.'
      admin_scope :write, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Claim prefixed ID'
      request_body_for(required: false)

      response '200', 'claim denied' do
        let(:id) { record.prefixed_id }
        let(:body) { { reason: 'Outside warranty' } }

        schema '$ref' => '#/components/schemas/Claim'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('denied')
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/claims/{id}/cancel' do
    patch 'Cancel a claim' do
      tags 'Orders'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Withdraws a claim that has not been resolved.'
      admin_scope :write, :orders

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :order_id, in: :path, type: :string, required: true, description: 'Order prefixed ID'
      parameter name: :id, in: :path, type: :string, required: true, description: 'Claim prefixed ID'
      request_body_for(required: false)

      response '200', 'claim canceled' do
        let(:id) { record.prefixed_id }
        let(:body) { { reason: 'Customer found the missing item' } }

        schema '$ref' => '#/components/schemas/Claim'

        run_test! do |response|
          expect(JSON.parse(response.body)['status']).to eq('canceled')
        end
      end
    end
  end
end
