require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::Products::MediaController, type: :controller do
  render_views

  include_context 'API v3 Seller authenticated'

  let!(:product) { create(:product, seller: seller, store: store) }
  let!(:media) { create(:media, viewable: product) }

  before { request.headers.merge!(headers) }

  describe 'DELETE #destroy' do
    it "removes a file from the seller's own product" do
      delete :destroy, params: { product_id: product.prefixed_id, id: media.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Media.where(id: media.id)).to be_empty
    end

    it "404s on another seller's product" do
      other = create(:product, seller: create(:seller, :approved, store: store), store: store)
      other_media = create(:media, viewable: other)

      delete :destroy, params: { product_id: other.prefixed_id, id: other_media.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::Media.where(id: other_media.id)).to exist
    end

    it "404s on a file from another of the seller's products" do
      sibling_media = create(:media, viewable: create(:product, seller: seller, store: store))

      delete :destroy, params: { product_id: product.prefixed_id, id: sibling_media.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::Media.where(id: sibling_media.id)).to exist
    end

    it 'leaves an approved listing on sale' do
      product.update_columns(status: 'active')

      delete :destroy, params: { product_id: product.prefixed_id, id: media.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(product.reload.status).to eq('active')
    end
  end
end
