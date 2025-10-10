require 'spec_helper'

describe 'Platform API v2 Digitals spec', type: :request do
  subject { post '/api/v2/platform/digitals', headers: bearer_token, params: params }

  include_context 'API v2 tokens'
  include_context 'Platform API v2'
  include ActionDispatch::TestProcess::FixtureFile

  let(:bearer_token) { { 'Authorization' => valid_authorization } }
  let(:params) { { digital: { variant_id: variant.id.to_s, attachment: file_upload } } }
  let(:variant) { create(:variant) }
  let(:file_upload) { fixture_file_upload(file_fixture('icon_256x256.jpg'), 'image/jpg') }

  context 'valid request' do
    it 'returns status created' do
      subject
      expect(response).to have_http_status :created
    end

    it 'creates a blob ' do
      expect { subject }.to change { ActiveStorage::Blob.count }.from(0).to(1)
    end
  end
end
