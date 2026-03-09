require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::AssetsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:product) { create(:product, stores: [store]) }

  before { request.headers.merge!(headers) }

  describe 'POST #create with signed_id' do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(
        io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
        filename: 'test-image.jpg',
        content_type: 'image/jpeg'
      )
    end

    it 'creates an asset from a signed blob ID' do
      post :create, params: {
        product_id: product.prefixed_id,
        signed_id: blob.signed_id,
        alt: 'Test image',
        position: 1
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to be_present
      expect(json_response['alt']).to eq('Test image')
    end
  end
end
