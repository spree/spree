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
      expect(address_data).to include('id', 'first_name', 'last_name', 'address1', 'city', 'postal_code')
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

      expect(json_response).to include('id', 'first_name', 'last_name', 'address1', 'city', 'postal_code')
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
        first_name: 'John',
        last_name: 'Doe',
        address1: '123 Main St',
        city: 'New York',
        postal_code: '10001',
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

      expect(json_response['first_name']).to eq('John')
      expect(json_response['last_name']).to eq('Doe')
      expect(json_response['address1']).to eq('123 Main St')
    end

    context 'with invalid params' do
      it 'returns validation errors for missing first_name' do
        post :create, params: address_params.except(:first_name)

        expect(response).to have_http_status(:unprocessable_content)
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
      patch :update, params: { id: address.prefixed_id, first_name: 'Updated' }

      expect(response).to have_http_status(:ok)
      expect(address.reload.firstname).to eq('Updated')
    end

    it 'returns the updated address' do
      patch :update, params: { id: address.prefixed_id, first_name: 'Updated' }

      expect(json_response['first_name']).to eq('Updated')
    end

    context 'when address belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_address) { create(:address, user: other_user) }

      it 'returns not found' do
        patch :update, params: { id: other_address.prefixed_id, first_name: 'Hacker' }

        expect(response).to have_http_status(:not_found)
        expect(other_address.reload.firstname).not_to eq('Hacker')
      end
    end

    context 'without authentication' do
      before { request.headers['Authorization'] = nil }

      it 'returns unauthorized' do
        patch :update, params: { id: address.prefixed_id, first_name: 'Updated' }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'is_default_billing / is_default_shipping' do
    describe 'response serialization' do
      it 'includes is_default_billing and is_default_shipping in index response' do
        user.update!(bill_address: address)

        get :index

        addr = json_response['data'].find { |a| a['id'] == address.prefixed_id }
        expect(addr['is_default_billing']).to eq(true)
        expect(addr['is_default_shipping']).to eq(false)
      end

      it 'includes is_default_billing and is_default_shipping in show response' do
        get :show, params: { id: address.prefixed_id }

        expect(json_response).to have_key('is_default_billing')
        expect(json_response).to have_key('is_default_shipping')
      end
    end

    describe 'POST #create' do
      let(:address_params) do
        {
          first_name: 'Jane',
          last_name: 'Smith',
          address1: '456 Oak Ave',
          city: 'Chicago',
          postal_code: '60601',
          phone: '555-9999',
          country_iso: country.iso,
          state_abbr: state.abbr
        }
      end

      it 'sets default billing on create' do
        post :create, params: address_params.merge(is_default_billing: true)

        expect(response).to have_http_status(:created)
        new_address = Spree::Address.find_by_prefix_id(json_response['id'])
        expect(user.reload.bill_address_id).to eq(new_address.id)
        expect(json_response['is_default_billing']).to eq(true)
      end

      it 'sets default shipping on create' do
        post :create, params: address_params.merge(is_default_shipping: true)

        expect(response).to have_http_status(:created)
        new_address = Spree::Address.find_by_prefix_id(json_response['id'])
        expect(user.reload.ship_address_id).to eq(new_address.id)
        expect(json_response['is_default_shipping']).to eq(true)
      end

      it 'sets both defaults on create' do
        post :create, params: address_params.merge(is_default_billing: true, is_default_shipping: true)

        expect(response).to have_http_status(:created)
        new_address = Spree::Address.find_by_prefix_id(json_response['id'])
        expect(user.reload.bill_address_id).to eq(new_address.id)
        expect(user.reload.ship_address_id).to eq(new_address.id)
      end
    end

    describe 'PATCH #update' do
      it 'sets address as default billing' do
        patch :update, params: { id: address.prefixed_id, is_default_billing: true }

        expect(response).to have_http_status(:ok)
        expect(user.reload.bill_address_id).to eq(address.id)
        expect(json_response['is_default_billing']).to eq(true)
      end

      it 'sets address as default shipping' do
        patch :update, params: { id: address.prefixed_id, is_default_shipping: true }

        expect(response).to have_http_status(:ok)
        expect(user.reload.ship_address_id).to eq(address.id)
        expect(json_response['is_default_shipping']).to eq(true)
      end

      it 'sets both defaults at once' do
        patch :update, params: { id: address.prefixed_id, is_default_billing: true, is_default_shipping: true }

        expect(response).to have_http_status(:ok)
        expect(user.reload.bill_address_id).to eq(address.id)
        expect(user.reload.ship_address_id).to eq(address.id)
      end

      it 'sets default and updates fields in one request' do
        patch :update, params: { id: address.prefixed_id, is_default_billing: true, city: 'Boston' }

        expect(response).to have_http_status(:ok)
        expect(user.reload.bill_address_id).to eq(address.id)
        expect(address.reload.city).to eq('Boston')
      end

      it 'does not change defaults when not passed' do
        user.update!(bill_address: address)

        patch :update, params: { id: address.prefixed_id, city: 'Denver' }

        expect(response).to have_http_status(:ok)
        expect(user.reload.bill_address_id).to eq(address.id)
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
