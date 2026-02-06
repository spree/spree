require 'spec_helper'

RSpec.describe Spree::Admin::AddressesController, type: :controller do
  stub_authorization!
  render_views

  let(:user) { create(:user) }
  let(:country) { Spree::Country.by_iso('US') || create(:country, iso: 'US', name: 'United States') }
  let(:state) { create(:state, name: 'California', abbr: 'CA', country: country) }

  describe 'GET #new' do
    it 'renders the new address form' do
      get :new, params: { type: 'shipping' }
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    subject { post :create, params: params, format: :turbo_stream }

    let(:params) { { address: address_params, user_id: user.to_param, type: 'shipping', default_shipping: true } }

    let(:address_params) do
      {
        firstname: 'John',
        lastname: 'Doe',
        address1: '100 California Street',
        city: 'San Francisco',
        country_id: country.id,
        state_id: state.id,
        zipcode: '94111'
      }
    end

    let(:address) { Spree::Address.last }

    it 'creates a new address and renders turbo_stream' do
      expect { subject }.to change(Spree::Address, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')

      expect(address.user).to eq(user)
      expect(address.firstname).to eq('John')
      expect(address.lastname).to eq('Doe')
      expect(address.address1).to eq('100 California Street')
      expect(address.city).to eq('San Francisco')
      expect(address.country).to eq(country)
      expect(address.state).to eq(state)
      expect(address.zipcode).to eq('94111')
    end

    context 'with default shipping' do
      let(:params) { { address: address_params, user_id: user.to_param, type: 'shipping', default_shipping: true } }

      it 'creates a new default shipping address' do
        expect { subject }.to change(Spree::Address, :count).by(1)
        expect(address).to be_user_default_shipping
      end
    end

    context 'with default billing' do
      let(:params) { { address: address_params, user_id: user.to_param, type: 'billing', default_billing: true } }

      it 'creates a new default billing address' do
        expect { subject }.to change(Spree::Address, :count).by(1)
        expect(address).to be_user_default_billing
      end
    end

    context 'with invalid params' do
      let(:address_params) { { firstname: '' } }

      it 'renders turbo_stream with form errors' do
        expect { subject }.not_to change(Spree::Address, :count)

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end

  describe 'GET #edit' do
    let(:address) { create(:address) }

    it 'renders the edit address form' do
      get :edit, params: { id: address.to_param, type: 'shipping' }
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    subject { put :update, params: params, format: :turbo_stream }

    let(:address) { create(:address, user: user, firstname: 'John', lastname: 'Doe') }
    let(:params) { { id: address.to_param, address: address_params, type: 'shipping' } }

    let(:address_params) do
      {
        firstname: 'Jane',
        lastname: 'Moe'
      }
    end

    it 'updates the address and renders turbo_stream' do
      expect { subject }.to change { address.reload.first_name }.to('Jane').and(
        change { address.reload.lastname }.to('Moe')
      )

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/vnd.turbo-stream.html')
    end

    context 'for a user with an incomplete order' do
      let!(:order) { create(:order, user: user, ship_address: address, state: 'payment') }

      it 'pushes the order to the address state' do
        expect { subject }.to change { order.reload.state }.to('address')
      end
    end

    context 'with invalid params' do
      let(:address_params) { { firstname: '' } }

      it 'renders turbo_stream with form errors' do
        subject

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end
    end
  end
end
