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

      admin_sdk_example 'products/digital-assets/list'

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

    post 'Create a product digital asset' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Attaches a downloadable file to one of the product's variants (the
        default variant when `variant_id` is omitted). Upload the file first
        through `POST /api/v3/admin/files` with `visibility: 'private'`, then
        send its `signed_id` here. A provider-backed asset sends
        `provider_type` and `provider_settings` instead of a file.
      DESC
      admin_scope :write, :products

      admin_sdk_example 'products/digital-assets/create'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      request_body_for

      response '201', 'digital asset created' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:blob) do
          ActiveStorage::Blob.create_and_upload!(
            io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
            filename: 'manual.pdf',
            content_type: 'application/pdf',
            service_name: Spree.private_storage_service_name
          )
        end
        let(:body) { { signed_id: blob.signed_id, authorized_clicks: 5, authorized_days: 30 } }

        schema '$ref' => '#/components/schemas/DigitalAsset'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['authorized_clicks']).to eq(5)
          expect(data['authorized_days']).to eq(30)
        end
      end
    end
  end

  path '/api/v3/admin/products/{product_id}/digital_assets/{id}' do
    parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Digital asset ID'

    patch 'Update a product digital asset' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [api_key: [], bearer_auth: []]
      description <<~DESC
        Changes an asset's download limits, or replaces its file with a new
        private `signed_id`. Links customers already received keep working and
        serve the new file.
      DESC
      admin_scope :write, :products

      admin_sdk_example 'products/digital-assets/update'

      parameter name: 'x-spree-api-key', in: :header, type: :string, required: true
      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer token for admin authentication'
      request_body_for

      response '200', 'digital asset updated' do
        let(:'x-spree-api-key') { secret_api_key.plaintext_token }
        let(:product_id) { product.prefixed_id }
        let(:id) { digital_asset.prefixed_id }
        let(:body) { { authorized_clicks: 10, authorized_days: nil } }

        schema '$ref' => '#/components/schemas/DigitalAsset'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['authorized_clicks']).to eq(10)
          expect(data['authorized_days']).to be_nil
        end
      end
    end
  end
end
