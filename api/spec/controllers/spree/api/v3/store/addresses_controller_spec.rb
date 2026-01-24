require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::AddressesController, type: :controller do
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
    it 'returns user addresses' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_present
    end

    it 'returns pagination metadata' do
      get :index

      expect(json_response['meta']).to include('page', 'count', 'pages')
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        get :index

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'GET #show' do
    it 'returns the address' do
      get :show, params: { id: address.id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(address.id)
      expect(json_response['firstname']).to eq(address.firstname)
      expect(json_response['lastname']).to eq(address.lastname)
    end

    context 'error handling' do
      it 'returns not found for non-existent address' do
        get :show, params: { id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for other users address' do
        other_user = create(:user)
        other_address = create(:address, user: other_user)

        get :show, params: { id: other_address.id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        address: {
          firstname: 'John',
          lastname: 'Doe',
          address1: '123 Main St',
          city: 'New York',
          zipcode: '10001',
          phone: '555-1234',
          country_id: country.id,
          state_id: state.id
        }
      }
    end

    it 'creates a new address' do
      expect {
        post :create, params: valid_params
      }.to change(Spree::Address, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['firstname']).to eq('John')
      expect(json_response['lastname']).to eq('Doe')
    end

    it 'associates address with current user' do
      post :create, params: valid_params

      expect(Spree::Address.last.user_id).to eq(user.id)
    end

    context 'validation errors' do
      it 'returns errors for missing required fields' do
        post :create, params: { address: { firstname: 'John' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns errors for blank firstname' do
        post :create, params: { address: valid_params[:address].merge(firstname: '') }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['firstname']).to be_present
      end

      it 'returns errors for invalid country' do
        post :create, params: { address: valid_params[:address].merge(country_id: 0) }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['country']).to be_present
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        post :create, params: valid_params

        expect(response).to have_http_status(:unauthorized)
        expect(json_response['error']['code']).to eq('authentication_required')
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the address' do
      patch :update, params: { id: address.id, address: { address1: 'Updated Street' } }

      expect(response).to have_http_status(:ok)
      expect(address.reload.address1).to eq('Updated Street')
    end

    it 'updates multiple fields' do
      patch :update, params: {
        id: address.id,
        address: { firstname: 'Jane', lastname: 'Smith', city: 'Boston' }
      }

      expect(response).to have_http_status(:ok)
      address.reload
      expect(address.firstname).to eq('Jane')
      expect(address.lastname).to eq('Smith')
      expect(address.city).to eq('Boston')
    end

    context 'validation errors' do
      it 'returns errors for invalid update' do
        patch :update, params: { id: address.id, address: { firstname: '' } }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response['error']['code']).to eq('validation_error')
        expect(json_response['error']['details']['firstname']).to be_present
      end
    end

    context 'error handling' do
      it 'returns not found for other users address' do
        other_user = create(:user)
        other_address = create(:address, user: other_user)

        patch :update, params: { id: other_address.id, address: { address1: 'Hack Street' } }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the address' do
      expect {
        delete :destroy, params: { id: address.id }
      }.to change(Spree::Address, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    context 'error handling' do
      it 'returns not found for non-existent address' do
        delete :destroy, params: { id: 0 }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
        expect(json_response['error']['message']).to be_present
      end

      it 'returns not found for other users address' do
        other_user = create(:user)
        other_address = create(:address, user: other_user)

        delete :destroy, params: { id: other_address.id }

        expect(response).to have_http_status(:not_found)
        expect(json_response['error']['code']).to eq('record_not_found')
      end
    end
  end
end
