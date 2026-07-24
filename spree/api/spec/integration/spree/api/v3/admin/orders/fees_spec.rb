# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Fees API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let!(:fee) { create(:fee, line_item: order.line_items.first, order: order) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/fees' do
    let(:order_id) { order.prefixed_id }

    get 'List fees' do
      tags 'Fees'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all fees for an order. Read-only: fees are written by registered adjusters.'
      admin_scope :read, :orders

      admin_sdk_example 'order-fees/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'fees found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].first['id']).to eq(fee.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/fees/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { fee.prefixed_id }

    get 'Get a fee' do
      tags 'Fees'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :orders

      admin_sdk_example 'order-fees/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'fee found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(fee.prefixed_id)
        end
      end
    end
  end
end
