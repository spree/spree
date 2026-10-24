require 'spec_helper'

# The writes themselves run through the digital asset workflows (covered by
# their own spec and the admin controller spec); this covers what the seller
# branch adds: tenancy, the seller's role, the marketplace's rules for a
# seller's file, and that providers stay the operator's.
RSpec.describe Spree::Api::V3::Seller::Products::DigitalAssetsController, type: :controller do
  render_views

  include_context 'API v3 Seller authenticated'

  let!(:product) { create(:product, seller: seller, store: store) }
  let(:variant) { product.default_variant }
  let(:other_seller) { create(:seller, :approved, store: store) }

  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
      filename: 'amp-model.nam',
      content_type: 'application/octet-stream',
      service_name: Spree.private_storage_service_name
    )
  end

  before do
    request.headers.merge!(headers)
    stub_store_preferences(seller_digital_assets_enabled: true)
  end

  describe 'GET #index' do
    let!(:digital_asset) { create(:digital_asset, variant: variant, authorized_clicks: 5) }

    it "lists the files on the seller's own product" do
      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to eq([digital_asset.prefixed_id])
      expect(json_response['data'].first).to include('authorized_clicks' => 5, 'effective_authorized_clicks' => 5)
      expect(json_response['data'].first['download_url']).to be_present
    end

    it "keeps the operator's provider settings to the operator" do
      digital_asset.update!(metadata: { 'provider' => { 'pool_name' => 'internal' } })

      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(json_response['data'].first).not_to have_key('provider_settings')
    end

    it "404s on another seller's product" do
      theirs = create(:product, seller: other_seller, store: store)
      create(:digital_asset, variant: theirs.default_variant)

      get :index, params: { product_id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "404s on the marketplace's own product" do
      get :index, params: { product_id: create(:product, store: store).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'attaches an uploaded file with its own download limits' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        authorized_clicks: 3,
        authorized_days: 30
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response).to include('filename' => 'amp-model.nam', 'variant_id' => variant.prefixed_id,
                                       'authorized_clicks' => 3, 'authorized_days' => 30)
    end

    it 'refuses an upload it cannot find' do
      post :create, params: { product_id: product.prefixed_id, signed_id: 'expired' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('error', 'message')).to match(/could not be found/)
    end

    it "refuses a variant of another seller's product" do
      theirs = create(:product, seller: other_seller, store: store)

      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        variant_id: theirs.default_variant.prefixed_id
      }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(Spree::DigitalAsset.count).to eq(0)
    end

    context 'with a provider registered by the operator' do
      let(:stub_provider) do
        Class.new(Spree::DigitalAssetProvider::Base) do
          def self.requires_attachment? = false
          def deliver(_link, expires_in:) = Spree::DigitalDelivery.new(inline_value: 'X')
        end
      end

      before do
        stub_const('Spree::DigitalAssetProvider::Stub', stub_provider)
        Spree.digital_asset_providers << stub_provider
      end

      after { Spree.digital_asset_providers.delete(stub_provider) }

      it "refuses a file on an asset the operator's provider delivers" do
        digital_asset = create(:digital_asset, variant: variant)
        digital_asset.attachment.purge
        digital_asset.update!(provider_type: 'Spree::DigitalAssetProvider::Stub')

        patch :update, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id,
                                 signed_id: blob.signed_id }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(digital_asset.reload.attachment).not_to be_attached
      end

      it 'cannot route a sale through it' do
        post :create, params: { product_id: product.prefixed_id, provider_type: 'stub' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(Spree::DigitalAsset.count).to eq(0)
      end
    end
  end

  describe 'PATCH #update' do
    let!(:digital_asset) { create(:digital_asset, variant: variant, authorized_days: 7) }

    context 'with attributes an extension opened' do
      around do |example|
        operator_attributes = Spree::DigitalAsset.additional_permitted_attributes
        seller_attributes = Spree::DigitalAsset.additional_seller_permitted_attributes
        example.run
      ensure
        Spree::DigitalAsset.additional_permitted_attributes = operator_attributes
        Spree::DigitalAsset.additional_seller_permitted_attributes = seller_attributes
      end

      it 'saves one opened to sellers' do
        Spree::DigitalAsset.additional_seller_permitted_attributes += [{ metadata: {} }]

        patch :update, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id,
                                 metadata: { 'note' => 'seller' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(digital_asset.reload.metadata).to include('note' => 'seller')
      end

      it 'ignores one opened to operators only' do
        Spree::DigitalAsset.additional_permitted_attributes += [{ metadata: {} }]

        patch :update, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id,
                                 metadata: { 'note' => 'operator' } }, as: :json

        expect(response).to have_http_status(:ok)
        expect(digital_asset.reload.metadata).not_to include('note')
      end
    end

    it 'replaces the file and clears a limit back to the store default' do
      patch :update, params: {
        product_id: product.prefixed_id,
        id: digital_asset.prefixed_id,
        signed_id: blob.signed_id,
        authorized_days: nil
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['filename']).to eq('amp-model.nam')
      expect(json_response['authorized_days']).to be_nil
    end
  end

  describe "the marketplace's rules for a seller's file" do
    it 'refuses every file when the marketplace has not opened uploads to sellers' do
      stub_store_preferences(seller_digital_assets_enabled: false)

      post :create, params: { product_id: product.prefixed_id, signed_id: blob.signed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('error', 'message')).to match(/does not accept files uploaded by sellers/)
      expect(Spree::DigitalAsset.count).to eq(0)
    end

    # The blob declares itself a generic binary; its bytes are a JPEG, and the
    # bytes are what the rule reads.
    it 'judges the content type from the bytes against the accepted list' do
      stub_store_preferences(seller_digital_asset_content_types: %w[application/pdf])

      post :create, params: { product_id: product.prefixed_id, signed_id: blob.signed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig('error', 'message')).to match(%r{image/jpeg files are not accepted})
      expect(Spree::DigitalAsset.count).to eq(0)
    end

    it 'leaves the limits editable when the type is no longer accepted' do
      digital_asset = create(:digital_asset, variant: variant)
      stub_store_preferences(seller_digital_asset_content_types: %w[application/pdf])

      patch :update, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id, authorized_clicks: 2 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(digital_asset.reload.authorized_clicks).to eq(2)
    end

    context 'on a listing already on sale' do
      before { product.update!(status: 'active') }

      it 'sends the product back to review when a file is added, naming who did it and why' do
        post :create, params: { product_id: product.prefixed_id, signed_id: blob.signed_id }, as: :json

        expect(response).to have_http_status(:created)
        expect(product.reload).to be_proposed
        submission = product.submissions.latest_first.first
        expect(submission.status).to eq('pending')
        expect(submission.submitted_by).to eq(seller_user)
        expect(submission.metadata).to include('reason' => 'digital_asset_changed')
      end

      it 'sends the product back to review when a file is replaced' do
        digital_asset = create(:digital_asset, variant: variant)

        patch :update, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id, signed_id: blob.signed_id }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload).to be_proposed
      end

      it 'leaves the product on sale when only the limits change' do
        digital_asset = create(:digital_asset, variant: variant)

        patch :update, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id, authorized_clicks: 2 }, as: :json

        expect(response).to have_http_status(:ok)
        expect(product.reload).to be_active
      end

      it 'leaves the product on sale when the marketplace does not review file changes' do
        stub_store_preferences(review_seller_digital_asset_changes: false)

        post :create, params: { product_id: product.prefixed_id, signed_id: blob.signed_id }, as: :json

        expect(response).to have_http_status(:created)
        expect(product.reload).to be_active
      end

      it 'leaves the product on sale when the marketplace approves seller products automatically' do
        stub_store_preferences(auto_approve_seller_products: true)

        post :create, params: { product_id: product.prefixed_id, signed_id: blob.signed_id }, as: :json

        expect(response).to have_http_status(:created)
        expect(product.reload).to be_active
        expect(product.submissions).to be_empty
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:digital_asset) { create(:digital_asset, variant: variant) }

    it 'removes the file' do
      delete :destroy, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::DigitalAsset.where(id: digital_asset.id)).to be_empty
    end
  end

  context 'with a read-only role' do
    let(:seller_role) { create(:role, name: 'Viewer', resource: seller, permissions: %w[read_products]) }
    let!(:digital_asset) { create(:digital_asset, variant: variant) }

    it 'lists the files' do
      get :index, params: { product_id: product.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'cannot add one' do
      post :create, params: { product_id: product.prefixed_id, signed_id: blob.signed_id }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Spree::DigitalAsset.count).to eq(1)
    end

    it 'cannot change one' do
      patch :update, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id, authorized_clicks: 1 }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(digital_asset.reload.authorized_clicks).to be_nil
    end

    it 'cannot remove one' do
      delete :destroy, params: { product_id: product.prefixed_id, id: digital_asset.prefixed_id }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(Spree::DigitalAsset.where(id: digital_asset.id)).to exist
    end
  end
end
