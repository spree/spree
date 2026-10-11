# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Imports API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:product_import) { create(:product_import, store: store, seller: seller, user: seller_user) }

  path '/api/v3/seller/imports' do
    get 'List imports' do
      tags 'Imports'
      produces 'application/json'
      security [bearer_auth: []]
      description "This seller's product CSV imports, queued or finished. Another seller's imports are never listed."

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      filter_parameters_for

      response '200', 'imports listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        before { create(:product_import, :for_seller, store: store) }

        schema SwaggerSchemaHelpers.paginated('Import')

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to eq([product_import.prefixed_id])
        end
      end
    end
  end

  path '/api/v3/seller/imports/{import_id}/rows' do
    parameter name: :import_id, in: :path, type: :string, required: true, description: 'Import prefixed ID'

    get 'List import rows' do
      tags 'Imports'
      produces 'application/json'
      security [bearer_auth: []]
      description "The rows of one of this seller's imports, each with its status and any validation errors."

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      filter_parameters_for

      response '200', 'rows listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:import_id) { product_import.prefixed_id }
        let!(:import_row) { create(:import_row, import: product_import) }

        schema SwaggerSchemaHelpers.paginated('ImportRow')

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to eq([import_row.prefixed_id])
        end
      end
    end
  end
end
