require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::StoresController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  describe 'Spree::Api::V3::SecurityHeaders' do
    it 'sets X-Content-Type-Options header' do
      get :show

      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
    end

    it 'sets X-Frame-Options header' do
      get :show

      expect(response.headers['X-Frame-Options']).to eq('DENY')
    end

    it 'sets X-Request-Id header' do
      allow_any_instance_of(ActionDispatch::Request).to receive(:request_id).and_return('test-request-id-123')

      get :show

      expect(response.headers['X-Request-Id']).to eq('test-request-id-123')
    end

    it 'removes X-Powered-By header' do
      get :show

      expect(response.headers['X-Powered-By']).to be_nil
    end

    it 'removes Server header' do
      get :show

      expect(response.headers['Server']).to be_nil
    end
  end
end
