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

    it 'gives each file a download link so the merchant can check it' do
      get :index, params: { product_id: product.prefixed_id }

      expect(json_response['data'].first['download_url']).to be_present
    end

    it 'does not list assets belonging to another product' do
      other = create(:digital_asset)

      get :index, params: { product_id: product.prefixed_id }

      expect(json_response['data'].map { |a| a['id'] }).not_to include(other.prefixed_id)
    end

    # Assets reach the product through `variants`, which orders by the variants
    # table — combined with the collection's DISTINCT that is invalid on
    # PostgreSQL, so the listing must order by the assets' own table. Asserting
    # the order keeps this honest on SQLite too, where the bad query still runs.
    it 'returns the assets oldest first, across variants' do
      second_variant = create(:variant, product: product)
      newer = create(:digital_asset, variant: second_variant, created_at: 1.hour.from_now)

      get :index, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |a| a['id'] }).to eq([digital_asset.prefixed_id, newer.prefixed_id])
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

  describe 'GET #providers' do
    it 'lists the registered sources, including the File default' do
      get :providers, params: { product_id: product.prefixed_id }

      expect(response).to have_http_status(:ok)
      types = json_response['data'].map { |p| p['type'] }
      expect(types).to include('Spree::DigitalAssetProvider::File')
      file = json_response['data'].find { |p| p['type'] == 'Spree::DigitalAssetProvider::File' }
      expect(file['requires_attachment']).to be(true)
      expect(file['settings_schema']).to eq([])
    end
  end

  describe 'provider_type' do
    let(:stub_provider) do
      Class.new(Spree::DigitalAssetProvider::Base) do
        def self.requires_attachment? = false
        setting :pool_name, :string
        def deliver(_link, expires_in:) = Spree::DigitalDelivery.new(inline_value: 'X')
      end
    end

    before do
      stub_const('Spree::DigitalAssetProvider::Stub', stub_provider)
      Spree.digital_asset_providers << stub_provider
    end

    after { Spree.digital_asset_providers.delete(stub_provider) }

    it 'advertises the provider settings schema for the source picker' do
      get :providers, params: { product_id: product.prefixed_id }

      stub = json_response['data'].find { |p| p['type'] == 'Spree::DigitalAssetProvider::Stub' }
      expect(stub['settings_schema']).to eq([{ 'key' => 'pool_name', 'type' => 'string' }])
    end

    it 'creates a provider-backed asset with no file' do
      post :create, params: {
        product_id: product.prefixed_id,
        provider_type: 'Spree::DigitalAssetProvider::Stub'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['provider_type']).to eq('Spree::DigitalAssetProvider::Stub')
    end

    it 'stores the provider settings on the asset' do
      post :create, params: {
        product_id: product.prefixed_id,
        provider_type: 'Spree::DigitalAssetProvider::Stub',
        provider_settings: { pool_name: 'winter-sale' }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['provider_settings']).to eq('pool_name' => 'winter-sale')
      expect(Spree::DigitalAsset.last.provider_settings).to eq('pool_name' => 'winter-sale')
    end

    it 'rejects an unregistered provider_type' do
      post :create, params: {
        product_id: product.prefixed_id,
        provider_type: 'Spree::DigitalAssetProvider::Nope'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
