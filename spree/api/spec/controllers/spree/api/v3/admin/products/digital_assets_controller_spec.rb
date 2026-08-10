require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Products::DigitalAssetsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, store: store) }
  let(:variant) { product.default_variant }

  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
      filename: 'manual.pdf',
      content_type: 'application/pdf',
      service_name: Spree.private_storage_service_name
    )
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:digital_asset) { create(:digital_asset, variant: variant) }

    it 'lists the assets for the product' do
      get :index, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |a| a['id'] }).to include(digital_asset.prefixed_id)
    end

    it 'does not list assets belonging to another product' do
      other = create(:digital_asset)

      get :index, params: { product_id: product.prefixed_id }

      expect(json_response['data'].map { |a| a['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'POST #create' do
    it 'attaches an uploaded file to the default variant' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['filename']).to eq('manual.pdf')
      expect(json_response['variant_id']).to eq(variant.prefixed_id)
    end

    it 'accepts per-asset download limits' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        authorized_clicks: 99,
        authorized_days: 365
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['authorized_clicks']).to eq(99)
      expect(json_response['effective_authorized_clicks']).to eq(99)
    end

    it 'rejects a file with no attachment' do
      post :create, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects a non-positive limit' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        authorized_clicks: 0
      }, as: :json

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'PATCH #update' do
    let!(:digital_asset) { create(:digital_asset, variant: variant) }

    it 'replaces the file, keeping existing links working' do
      digital_link = create(:digital_link, digital_asset: digital_asset)

      patch :update, params: {
        product_id: product.prefixed_id,
        id: digital_asset.prefixed_id,
        signed_id: blob.signed_id
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['filename']).to eq('manual.pdf')
      expect(digital_link.reload).to be_authorizable
    end

    it 'clears a limit override back to the store default' do
      digital_asset.update!(authorized_clicks: 50)

      patch :update, params: {
        product_id: product.prefixed_id,
        id: digital_asset.prefixed_id,
        authorized_clicks: nil
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['authorized_clicks']).to be_nil
    end
  end

  describe 'DELETE #destroy' do
    let!(:digital_asset) { create(:digital_asset, variant: variant) }

    it 'removes the asset' do
      delete :destroy, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id }

      expect(response).to have_http_status(:no_content)
      expect(Spree::DigitalAsset.where(id: digital_asset.id)).to be_empty
    end
  end

  context 'with a product from another store' do
    let(:other_product) { create(:product, store: create(:store)) }

    it 'returns not found' do
      get :index, params: { product_id: other_product.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
