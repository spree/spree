require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::DataRequestConfirmationsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:data_request) { create(:data_request, :awaiting_confirmation, store: store, customer: user) }
  let(:token) { data_request.generate_token_for(:confirmation) }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'POST #create' do
    it 'confirms the request and queues the work' do
      expect {
        post :create, params: { token: token }, as: :json
      }.to have_enqueued_job(Spree::DataRequests::ProcessJob)

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('pending')
    end

    it 'needs no signed-in session, because the link may be opened on another device' do
      post :create, params: { token: token }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'refuses a token that does not match' do
      post :create, params: { token: 'not-a-token' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(data_request.reload).to be_awaiting_confirmation
    end

    it 'refuses a request left unconfirmed past the window' do
      data_request.update_columns(requested_at: (Spree::DataRequest::CONFIRMATION_WINDOW + 1.minute).ago)

      post :create, params: { token: token }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(data_request.reload).to be_lapsed
    end
  end
end
