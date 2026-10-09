# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Admin Product Digital Assets API', type: :request, swagger_doc: 'api-reference/admin.yaml' do
  include_context 'API v3 Admin'

  let!(:product) { create(:product, store: store) }
  let!(:digital_asset) { create(:digital_asset, variant: product.default_variant) }
  let(:Authorization) { "Bearer #{admin_jwt_token}" }

  path '/api/v3/admin/products/{product_id}/digital_assets' do
    parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'

    get 'List product digital assets' do
      tags 'Products'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description "Returns the downloadable files attached to the product's variants, oldest first."
      admin_scope :read, :products

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Number of records per page'
      filter_parameters_for

      response '200', 'digital assets found' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }

        schema SwaggerSchemaHelpers.paginated('DigitalAsset')

        run_test! do |response|
          ids = JSON.parse(response.body)['data'].map { |record| record['id'] }
          expect(ids).to eq([digital_asset.prefixed_id])
        end
      end
    end
  end
end
