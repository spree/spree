require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::DataRequestsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:data_request) { create(:data_request, store: store, customer: user) }
  let(:token) { data_request.generate_token_for(:confirmation) }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'GET #show' do
    it 'shows the request to whoever holds the emailed token' do
      get :show, params: { token: token }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(data_request.prefixed_id)
    end

    # The token is what reached the request's address, so this is the one
    # place the API shows the link to a finished export.
    it 'shows the export link once the file is ready' do
      Spree::DataRequests::Fulfill.call(data_request: data_request)

      get :show, params: { token: token }, as: :json

      expect(json_response['download_url']).to include(data_request.reload.download_token)
      expect(response.headers['Cache-Control']).to include('no-store')
    end

    it 'finds nothing for a token that does not match' do
      get :show, params: { token: 'not-a-token' }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'finds nothing for a request in another store' do
      other_request = create(:data_request, store: create(:store), customer: user)

      get :show, params: { token: other_request.generate_token_for(:confirmation) }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
