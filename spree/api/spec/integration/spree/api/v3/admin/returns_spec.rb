# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Returns API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:record) { create(:return, order: create(:shipped_order, store: store)) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }
  let(:'x-spree-api-key') { secret_api_key.plaintext_token }

  path '/api/v3/admin/returns' do
    get 'List returns' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'Every return in the store, across all orders.'
      admin_scope :read, :orders

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
  end

  path '/api/v3/admin/orders/{order_id}/returns/{return_id}/labels' do
    get 'List return labels' do
      tags 'Orders'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description 'The shipping labels issued for sending one return back to the store.'
      admin_scope :read, :orders

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
