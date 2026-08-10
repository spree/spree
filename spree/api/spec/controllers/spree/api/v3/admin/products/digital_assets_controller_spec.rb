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

    # Dev and test collapse both storage services onto one, so the distinction
    # only exists in a deployed configuration — stub it to exercise the guard.
    it 'refuses a file uploaded to public storage' do
      # The blob is built first, then the expected service is changed, so the
      # already-uploaded file looks like it landed on the wrong bucket.
      signed_id = blob.signed_id
      allow(Spree).to receive(:private_storage_service_name).and_return(:private_bucket)

      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: signed_id
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(Spree::DigitalAsset.count).to eq(0)
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

  # variant_id arrives from the client, so it must be resolved through the
  # parent product rather than trusted — otherwise an asset can be planted on
  # another product's (or another store's) variant, and its files would be
  # issued and emailed to that store's customers.
  describe 'variant scoping' do
    let(:other_store) { create(:store) }
    let(:foreign_variant) { create(:product, store: other_store).default_variant }
    let(:sibling_variant) { create(:product, store: store).default_variant }

    it 'refuses to create an asset on another store\'s variant' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        variant_id: foreign_variant.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::DigitalAsset.where(variant_id: foreign_variant.id)).to be_empty
    end

    it 'refuses to create an asset on a variant of another product in the same store' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        variant_id: sibling_variant.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::DigitalAsset.where(variant_id: sibling_variant.id)).to be_empty
    end

    it 'refuses to relocate an existing asset onto a foreign variant' do
      digital_asset = create(:digital_asset, variant: variant)

      patch :update, params: {
        product_id: product.prefixed_id,
        id: digital_asset.prefixed_id,
        variant_id: foreign_variant.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(digital_asset.reload.variant_id).to eq(variant.id)
    end

    it 'accepts a variant that belongs to the parent product' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        variant_id: variant.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['variant_id']).to eq(variant.prefixed_id)
    end
  end
end
