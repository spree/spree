require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DirectUploadsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  describe 'POST #create' do
    before { request.headers.merge!(headers) }

    let(:blob_params) do
      {
        blob: {
          filename: 'test-image.jpg',
          byte_size: 1024,
          checksum: 'dGVzdA==',
          content_type: 'image/jpeg'
        }
      }
    end

    it 'creates a direct upload and returns presigned URL' do
      post :create, params: blob_params, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['signed_id']).to be_present
      expect(json_response['direct_upload']).to be_present
      expect(json_response['direct_upload']['url']).to be_present
      expect(json_response['direct_upload']['headers']).to be_a(Hash)
    end

    context 'without API key' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        post :create, params: blob_params, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
