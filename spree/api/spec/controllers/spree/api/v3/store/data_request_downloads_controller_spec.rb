require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::DataRequestDownloadsController, type: :controller do
  include_context 'API v3 Store'

  let(:data_request) { create(:data_request, store: store, customer: user) }

  describe 'GET #show' do
    context 'once the export is ready' do
      before { Spree::DataRequests::Fulfill.call(data_request: data_request) }

      it 'hands over the file itself' do
        get :show, params: { token: data_request.reload.download_token }

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).dig('account', 'email')).to eq(user.email)
      end

      it 'offers it as a download rather than rendering it' do
        get :show, params: { token: data_request.reload.download_token }

        expect(response.headers['Content-Disposition']).to include('attachment')
      end

      # Streamed rather than redirected to storage, so the export never lands
      # in a shared cache under some bucket's own policy.
      it 'tells caches not to keep it' do
        get :show, params: { token: data_request.reload.download_token }

        expect(response.headers['Cache-Control']).to include('no-store')
      end

      it 'needs no signed-in session, because the link arrives by email' do
        request.headers['Authorization'] = nil

        get :show, params: { token: data_request.reload.download_token }

        expect(response).to have_http_status(:ok)
      end

      it 'refuses once the request has expired' do
        data_request.reload.update!(expires_at: 1.day.ago)

        get :show, params: { token: data_request.download_token }

        expect(response).to have_http_status(:forbidden)
      end
    end

    it 'refuses while the export is still being built' do
      get :show, params: { token: data_request.download_token }

      expect(response).to have_http_status(:forbidden)
    end

    it 'refuses an unknown token' do
      get :show, params: { token: 'not-a-real-token' }

      expect(response).to have_http_status(:forbidden)
    end
  end
end
