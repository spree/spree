require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::AddressesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let(:country) { create(:country) }
  let(:state) { create(:state, country: country) }
  let!(:address) { create(:address, user: user, country: country, state: state) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    it 'returns the user addresses' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(user.addresses.count)
    end

    it 'returns address attributes' do
      get :index

      address_data = json_response['data'].first
      expect(address_data).to include('id', 'firstname', 'lastname', 'address1', 'city', 'zipcode')
    end

    it 'only returns addresses belonging to the current user' do
      other_user = create(:user)
      other_address = create(:address, user: other_user)

      get :index

      ids = json_response['data'].map { |a| a['id'] }
      expect(ids).to include(address.prefixed_id)
      expect(ids).not_to include(other_address.prefixed_id)
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'returns the address' do
      get :show, params: { id: address.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(address.prefixed_id)
    end

    it 'returns address attributes' do
      get :show, params: { id: address.prefixed_id }

      expect(json_response).to include('id', 'firstname', 'lastname', 'address1', 'city', 'zipcode')
    end

    context 'when address belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_address) { create(:address, user: other_user) }

      it 'returns not found' do
        get :show, params: { id: other_address.prefixed_id }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :show, params: { id: address.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST #create' do
    let(:address_params) do
      {
        firstname: 'John',
        lastname: 'Doe',
        address1: '123 Main St',
        city: 'New York',
        zipcode: '10001',
        phone: '555-1234',
        country_iso: country.iso,
        state_abbr: state.abbr
      }
    end

    it 'creates a new address' do
      expect {
        post :create, params: address_params
      }.to change { user.addresses.count }.by(1)

      expect(response).to have_http_status(:created)
    end

    it 'returns the created address' do
      post :create, params: address_params

      expect(json_response['firstname']).to eq('John')
      expect(json_response['lastname']).to eq('Doe')
      expect(json_response['address1']).to eq('123 Main St')
    end

    context 'with invalid params' do
      it 'returns validation errors for missing firstname' do
        post :create, params: address_params.except(:firstname)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :create, params: address_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the address' do
      patch :update, params: { id: address.prefixed_id, firstname: 'Updated' }

      expect(response).to have_http_status(:ok)
      expect(address.reload.firstname).to eq('Updated')
    end

    it 'returns the updated address' do
      patch :update, params: { id: address.prefixed_id, firstname: 'Updated' }

      expect(json_response['firstname']).to eq('Updated')
    end

    context 'when address belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_address) { create(:address, user: other_user) }

      it 'returns not found' do
        patch :update, params: { id: other_address.prefixed_id, firstname: 'Hacker' }

        expect(response).to have_http_status(:not_found)
        expect(other_address.reload.firstname).not_to eq('Hacker')
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        patch :update, params: { id: address.prefixed_id, firstname: 'Updated' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the address' do
      expect {
        delete :destroy, params: { id: address.prefixed_id }
      }.to change { user.addresses.count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'when address belongs to another user' do
      let!(:other_user) { create(:user) }
      let!(:other_address) { create(:address, user: other_user) }

      it 'returns not found' do
        expect {
          delete :destroy, params: { id: other_address.prefixed_id }
        }.not_to change { Spree::Address.count }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        delete :destroy, params: { id: address.prefixed_id }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
