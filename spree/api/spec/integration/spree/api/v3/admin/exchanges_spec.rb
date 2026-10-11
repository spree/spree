# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Exchanges API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:record) { create(:exchange, order: create(:shipped_order, store: store)) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }

  path '/api/v3/admin/exchanges' do
    get 'List exchanges' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Every exchange in the store, across all orders.'
      admin_scope :read, :orders

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
  end
end
