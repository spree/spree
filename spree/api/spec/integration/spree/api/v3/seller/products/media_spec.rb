# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Seller Product Media API', type: :request, swagger_doc: 'api-reference/seller.yaml' do
  include_context 'API v3 Seller'

  let!(:product) { create(:product, seller: seller, store: store) }
  let!(:media) { create(:media, viewable: product) }
  let(:Authorization) { "Bearer #{seller_jwt_token}" }
  let(:'X-Spree-Seller-Id') { seller.prefixed_id }
  let(:product_id) { product.prefixed_id }

  path '/api/v3/seller/products/{product_id}/media/{id}' do
    parameter name: :product_id, in: :path, type: :string, required: true, description: 'Product ID'
    parameter name: :id, in: :path, type: :string, required: true, description: 'Media ID'

    let(:id) { media.prefixed_id }

    delete 'Delete a product media file' do
      tags 'Products'
      security [bearer_auth: []]
      description <<~DESC
        Removes a file from the product's gallery. Updating the product never removes a file it
        was not sent, so this is the only way to take one off.
      DESC

      seller_sdk_example 'products/media/delete'

      parameter name: 'X-Spree-Seller-Id', in: :header, type: :string, required: true

      response '204', 'media deleted' do
        run_test! do
          expect(Spree::Media.where(id: media.id)).to be_empty
        end
      end

      response '404', "another seller's product" do
        let(:product_id) { create(:product, seller: create(:seller, :approved, store: store), store: store).prefixed_id }

        run_test!
      end
    end
  end
end
