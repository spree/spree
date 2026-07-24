# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Order Tax Lines API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let!(:tax_line) { create(:tax_line, line_item: order.line_items.first, order: order) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/orders/{order_id}/tax_lines' do
    let(:order_id) { order.prefixed_id }

    get 'List tax lines' do
      tags 'Tax Lines'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Returns all tax lines for an order. Read-only: tax lines are maintained by the recalculation pipeline.'
      admin_scope :read, :orders

      admin_sdk_example 'order-tax-lines/list'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true,
                description: 'Order ID'

      response '200', 'tax lines found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']).to be_an(Array)
          expect(data['data'].first['id']).to eq(tax_line.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/admin/orders/{order_id}/tax_lines/{id}' do
    let(:order_id) { order.prefixed_id }
    let(:id) { tax_line.prefixed_id }

    get 'Get a tax line' do
      tags 'Tax Lines'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      admin_scope :read, :orders

      admin_sdk_example 'order-tax-lines/get'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :order_id, in: :path, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true

      response '200', 'tax line found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(tax_line.prefixed_id)
        end
      end
    end
  end
end
