require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::DataRequestsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'accepts an access request without doing the work inline' do
      post :create, as: :json

      expect(response).to have_http_status(:accepted)
      expect(json_response['kind']).to eq('access')
      expect(json_response['status']).to eq('pending')
    end

    it 'queues the build' do
      expect {
        post :create, as: :json
      }.to have_enqueued_job(Spree::DataRequests::ProcessJob)
    end

    it 'returns the request already in flight rather than starting another' do
      post :create, as: :json
      first_number = json_response['number']

      post :create, as: :json

      expect(json_response['number']).to eq(first_number)
      expect(Spree::DataRequest.where(customer_id: user.id).count).to eq(1)
    end

    describe 'an erasure request' do
      it 'asks for the account password' do
        post :create, params: { kind: 'erasure' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(Spree::DataRequest.where(kind: 'erasure').count).to eq(0)
      end

      it 'refuses the wrong password' do
        post :create, params: { kind: 'erasure', current_password: 'not-the-password' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'accepts the request when the password is right' do
        post :create, params: { kind: 'erasure', current_password: 'secret123' }, as: :json

        expect(response).to have_http_status(:accepted)
        expect(json_response['kind']).to eq('erasure')
      end
    end
  end

  describe 'GET #index' do
    let!(:own_request) { create(:data_request, store: store, customer: user) }
    let!(:someone_elses) { create(:data_request, store: store, customer: create(:user)) }

    it 'lists the customer\'s own requests' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |r| r['id'] }).to include(own_request.prefixed_id)
    end

    it 'never shows another person\'s request' do
      get :index, as: :json

      expect(json_response['data'].map { |r| r['id'] }).not_to include(someone_elses.prefixed_id)
    end
  end

  describe 'GET #show' do
    let!(:someone_elses) { create(:data_request, store: store, customer: create(:user)) }

    it '404s on another person\'s request' do
      get :show, params: { id: someone_elses.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'without a signed-in customer' do
    before { request.headers['Authorization'] = nil }

    it 'refuses to open a request' do
      post :create, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
