require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::AccountController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #show' do
    it 'returns the current user' do
      get :show

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(user.prefixed_id)
      expect(json_response['email']).to eq(user.email)
    end

    it 'returns user attributes' do
      get :show

      expect(json_response).to include('id', 'email', 'first_name', 'last_name')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :show

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with invalid token' do
      before { request.headers['Authorization'] = 'Bearer invalid' }

      it 'returns unauthorized' do
        get :show

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end

    context 'with expired token' do
      let(:expired_token) { Spree::Api::V3::TestingSupport.generate_jwt(user, expiration: -1.hour.to_i) }

      before { request.headers['Authorization'] = "Bearer #{expired_token}" }

      it 'returns unauthorized' do
        get :show

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the current user first name' do
      patch :update, params: { first_name: 'Updated' }

      expect(response).to have_http_status(:ok)
      expect(user.reload.first_name).to eq('Updated')
    end

    it 'updates multiple fields' do
      patch :update, params: { first_name: 'John', last_name: 'Doe' }

      expect(response).to have_http_status(:ok)
      user.reload
      expect(user.first_name).to eq('John')
      expect(user.last_name).to eq('Doe')
    end

    it 'returns updated user data' do
      patch :update, params: { first_name: 'Updated' }

      expect(json_response['first_name']).to eq('Updated')
    end

    context 'validation errors' do
      it 'returns errors for blank email' do
        patch :update, params: { email: '' }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['email']).to be_present
      end

      it 'returns errors for duplicate email' do
        other_user = create(:user)
        patch :update, params: { email: other_user.email }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['email']).to be_present
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        patch :update, params: { first_name: 'Updated' }

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end
  end
end
