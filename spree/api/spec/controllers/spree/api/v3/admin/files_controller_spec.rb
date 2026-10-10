require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::FilesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    let(:presigned_params) do
      { filename: 'photo.jpg', byte_size: 1024, checksum: Digest::MD5.base64digest('photo'), content_type: 'image/jpeg' }
    end
    let(:image) { Rack::Test::UploadedFile.new(Spree::Core::Engine.root.join('spec/fixtures/thinking-cat.jpg'), 'image/jpeg') }

    def uploaded_blob
      ActiveStorage::Blob.find_signed!(json_response['signed_id'])
    end

    it 'reserves a file on public storage and returns where to send the bytes' do
      post :create, params: presigned_params, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response).to include('filename' => 'photo.jpg', 'byte_size' => 1024, 'visibility' => 'public')
      expect(json_response['upload']).to include('method' => 'PUT', 'url' => be_present, 'headers' => be_a(Hash))
      expect(Time.zone.parse(json_response['expires_at'])).to be_within(1.minute).of(1.day.from_now)
      expect(uploaded_blob.store_id).to eq(store.id)
      expect(uploaded_blob.service_name).to eq(Spree.public_storage_service_name.to_s)
    end

    it 'puts a private upload on private storage, whatever its type' do
      post :create, params: presigned_params.merge(filename: 'book.epub', content_type: 'application/epub+zip', visibility: 'private'), as: :json

      expect(response).to have_http_status(:created)
      expect(uploaded_blob.service_name).to eq(Spree.private_storage_service_name.to_s)
    end

    it 'stores the bytes of a multipart upload and reads their type from the content' do
      post :create, params: { file: image, content_type: 'text/plain' }

      expect(response).to have_http_status(:created)
      expect(json_response['upload']).to be_nil
      expect(json_response).to include('filename' => 'thinking-cat.jpg', 'content_type' => 'image/jpeg')
      expect(uploaded_blob.store_id).to eq(store.id)
      expect(uploaded_blob.byte_size).to eq(File.size(image.path))
      expect(uploaded_blob.service.exist?(uploaded_blob.key)).to be(true)
    end

    it 'refuses a public upload of a type customers should not be served' do
      post :create, params: presigned_params.merge(filename: 'run.sh', content_type: 'application/x-sh'), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']).to have_key('content_type')
    end

    it 'refuses a presigned upload over the size limit' do
      allow(Spree::Config).to receive(:max_upload_size).and_return(1000)

      post :create, params: presigned_params, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']).to have_key('byte_size')
    end

    it 'holds a multipart upload to its own, lower limit' do
      allow(Spree::Config).to receive(:max_multipart_upload_size).and_return(100)

      post :create, params: { file: image }

      expect(response).to have_http_status(:unprocessable_content)
      expect(ActiveStorage::Blob.count).to eq(0)
    end

    it 'refuses an unknown visibility' do
      post :create, params: presigned_params.merge(visibility: 'secret'), as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']).to have_key('visibility')
    end

    it 'treats a file that is not a file as a presigned upload missing its checksum' do
      post :create, params: { file: 'abc', filename: 'a.png', content_type: 'image/png', byte_size: 3 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['details']).to have_key('checksum')
    end

    it 'requires a checksum for a presigned upload' do
      post :create, params: presigned_params.except(:checksum), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    context 'without API key' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        post :create, params: presigned_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
