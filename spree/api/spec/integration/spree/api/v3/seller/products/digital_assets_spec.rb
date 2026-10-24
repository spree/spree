# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Product Digital Assets API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:product) { create(:product, seller: seller, store: store) }
  let!(:digital_asset) { create(:digital_asset, variant: product.default_variant) }
  let(:Authorization) { "Bearer #{seller_jwt_token}" }
  let(:'X-Spree-Seller-Id') { seller.prefixed_id }
  let(:product_id) { product.prefixed_id }

  # The marketplace opens uploads to sellers in its settings; off by default.
  before { stub_store_preferences(seller_digital_assets_enabled: true) }

  path '/api/v3/seller/products/{product_id}/digital_assets' do
    parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'

    get 'List product digital assets' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]
      description "Returns the downloadable files on one of this seller's own products, oldest first."

      seller_sdk_example 'products/digital-assets/list'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'
      filter_parameters_for

      response '200', 'digital assets found' do
        schema SwaggerSchemaHelpers.paginated('DigitalAsset')

        run_test! do |response|
          ids = JSON.parse(response.body)['data'].pluck('id')
          expect(ids).to eq([digital_asset.prefixed_id])
        end
      end

      response '404', "another seller's product" do
        let(:product_id) { create(:product, seller: create(:seller, :approved, store: store), store: store).prefixed_id }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end

    post 'Create a product digital asset' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Attaches a downloadable file to one of the product's variants (the
        default variant when `variant_id` is omitted). Upload the file first
        through `POST /api/v3/seller/files` with `visibility: 'private'`, then
        send its `signed_id` here. Leave `authorized_clicks` and
        `authorized_days` out to use the marketplace's download settings.
      DESC

      seller_sdk_example 'products/digital-assets/create'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '201', 'digital asset created' do
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
          expect(data).to include('filename' => 'manual.pdf', 'authorized_clicks' => 5, 'authorized_days' => 30)
        end
      end

      response '422', 'no file sent' do
        let(:body) { { authorized_clicks: 5 } }

        schema '$ref' => '#/components/schemas/ErrorResponse'

        run_test!
      end
    end
  end

  path '/api/v3/seller/products/{product_id}/digital_assets/{id}' do
    parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Digital asset ID'

    let(:id) { digital_asset.prefixed_id }

    get 'Get a product digital asset' do
      tags 'Products'
      produces 'application/json'
      security [bearer_auth: []]

      seller_sdk_example 'products/digital-assets/get'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '200', 'digital asset found' do
        schema '$ref' => '#/components/schemas/DigitalAsset'

        run_test! do |response|
          expect(JSON.parse(response.body)['id']).to eq(digital_asset.prefixed_id)
        end
      end
    end

    patch 'Update a product digital asset' do
      tags 'Products'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        Changes a file's download limits, or replaces it with a new private
        `signed_id`. Links customers already received keep working and serve
        the new file.
      DESC

      seller_sdk_example 'products/digital-assets/update'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      request_body_for

      response '200', 'digital asset updated' do
        let(:body) { { authorized_clicks: 10, authorized_days: nil } }

        schema '$ref' => '#/components/schemas/DigitalAsset'

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['authorized_clicks']).to eq(10)
          expect(data['authorized_days']).to be_nil
        end
      end
    end

    delete 'Delete a product digital asset' do
      tags 'Products'
      security [bearer_auth: []]
      description 'Removes the file. Customers who already bought it can no longer download it.'

      seller_sdk_example 'products/digital-assets/delete'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'digital asset deleted' do
        run_test! do
          expect(Spree::DigitalAsset.where(id: digital_asset.id)).to be_empty
        end
      end
    end
  end
end
