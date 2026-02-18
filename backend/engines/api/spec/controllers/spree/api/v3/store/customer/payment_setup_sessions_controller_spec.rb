require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::PaymentSetupSessionsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:payment_method) { create(:bogus_payment_method, stores: [store]) }
  let!(:payment_setup_session) do
    create(:payment_setup_session,
           customer: user,
           payment_method: payment_method,
           external_data: { 'client_secret' => 'secret_123' })
  end

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    it 'creates a payment setup session' do
      post :create, params: {
        payment_method_id: payment_method.prefixed_id
      }

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to be_present
      expect(json_response['status']).to eq('pending')
      expect(json_response['payment_method_id']).to eq(payment_method.prefixed_id)
      expect(json_response['external_client_secret']).to be_present
    end

    context 'error handling' do
      it 'returns not found for non-existent payment method' do
        post :create, params: {
          payment_method_id: 'invalid'
        }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :create, params: {
          payment_method_id: payment_method.prefixed_id
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the payment setup session' do
      get :show, params: { id: payment_setup_session.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(payment_setup_session.prefixed_id)
      expect(json_response['status']).to eq('pending')
      expect(json_response['external_data']).to eq({ 'client_secret' => 'secret_123' })
    end

    context 'when session belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_session) { create(:payment_setup_session, customer: other_user, payment_method: payment_method) }

      it 'returns not found' do
        get :show, params: { id: other_session.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: payment_setup_session.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #complete' do
    it 'completes the payment setup session and saves a payment source' do
      patch :complete, params: {
        id: payment_setup_session.prefixed_id
      }

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('completed')
      expect(json_response['payment_source_id']).to be_present
      expect(json_response['payment_source_type']).to eq('Spree::CreditCard')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        patch :complete, params: {
          id: payment_setup_session.prefixed_id
        }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
