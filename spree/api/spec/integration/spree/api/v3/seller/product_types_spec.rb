# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Product Types API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  # Types are read under their own key, which the shared context's
  # products-only role omits.
  let(:seller_role) do
    create(:role, name: 'Seller', resource: seller, permissions: %w[write_products read_product_types])
  end

  let!(:product_type) { create(:product_type, store: store, name: 'Apparel') }

  path '/api/v3/seller/product_types' do
    get 'List product types' do
      tags 'Product Types'
      produces 'application/json'
      security [bearer_auth: []]
      description <<~DESC
        The product types a seller may list a product against.

        Read only. A type is the template that hands a product its option types
        and its delivery profile, so a seller picks one when listing; defining
        types is the marketplace's. Send the chosen `id` as `product_type_id`
        on the product.
      DESC

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Records per page (max 100)'

      response '200', 'product types listed' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }

        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/ProductType' } },
                 meta: { '$ref' => '#/components/schemas/PaginationMeta' }
               },
               required: %w[data meta]

        run_test! do |response|
          data = JSON.parse(response.body)['data']
          expect(data.map { |item| item['id'] }).to include(product_type.prefixed_id)
        end
      end
    end
  end

  path '/api/v3/seller/product_types/{id}' do
    get 'Get a product type' do
      tags 'Product Types'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true
      parameter name: :id, in: :path, type: :string, required: true, description: 'Product type ID'

      response '200', 'product type found' do
        let(:Authorization) { "Bearer #{seller_jwt_token}" }
        let(:'X-Spree-Seller-Id') { seller.prefixed_id }
        let(:id) { product_type.prefixed_id }

        schema '$ref' => '#/components/schemas/ProductType'

        run_test! do |response|
          expect(JSON.parse(response.body)['name']).to eq('Apparel')
        end
      end
    end
  end
end
