require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Products::AssetsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, stores: [store]) }
  let!(:image) { create(:image, viewable: product.master) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns assets for the product' do
      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      ids = json_response['data'].map { |a| a['id'] }
      expect(ids).to include(image.prefixed_id)
    end

    context 'with product from another store' do
      let(:other_store) { create(:store) }
      let(:other_product) { create(:product, stores: [other_store]) }

      it 'returns 404' do
        get :index, params: { product_id: other_product.prefixed_id }, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    it 'returns validation error without attachment' do
      post :create, params: {
        product_id: product.prefixed_id,
        alt: 'New image',
        position: 1
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates the asset alt text' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: image.prefixed_id,
        alt: 'Updated alt text'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['alt']).to eq('Updated alt text')
      expect(image.reload.alt).to eq('Updated alt text')
    end

    it 'updates the asset position' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: image.prefixed_id,
        position: 5
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(image.reload.position).to eq(5)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the asset' do
      expect {
        delete :destroy, params: {
          product_id: product.prefixed_id,
          id: image.prefixed_id
        }, as: :json
      }.to change(product.master.images, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
