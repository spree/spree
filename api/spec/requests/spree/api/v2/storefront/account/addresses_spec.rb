require 'spec_helper'

describe 'Storefront API v2 Addresses spec', type: :request do
  let!(:user) { create(:user) }
  let!(:params) { { user_id: user.id } }
  let!(:addresses) { create_list(:address, 3, user_id: user.id) }
  let!(:country) { create(:country, iso: 'GBR') }
  let!(:state) { create(:state, country: country) }
  let(:store) { @default_store }

  shared_examples 'returns valid user addresses resource JSON' do
    it 'returns a valid user addresses resource JSON response' do
      expect(response.status).to eq(200)

      expect(json_response['data'][0]).to have_type('address')
      expect(json_response['data'][0]).to have_attribute(:firstname)
      expect(json_response['data'][0]).to have_attribute(:lastname)
      expect(json_response['data'][0]).to have_attribute(:address1)
      expect(json_response['data'][0]).to have_attribute(:address2)
      expect(json_response['data'][0]).to have_attribute(:city)
      expect(json_response['data'][0]).to have_attribute(:zipcode)
      expect(json_response['data'][0]).to have_attribute(:phone)
      expect(json_response['data'][0]).to have_attribute(:state_name)
      expect(json_response['data'][0]).to have_attribute(:company)
      expect(json_response['data'][0]).to have_attribute(:country_name)
      expect(json_response['data'][0]).to have_attribute(:country_iso3)
      expect(json_response['data'][0]).to have_attribute(:country_iso)
      expect(json_response['data'][0]).to have_attribute(:state_code)
      expect(json_response['data'][0]).to have_attribute(:public_metadata)
    end
  end

  include_context 'API v2 tokens'

  describe 'addresses#index' do
    context 'without options' do
      let!(:other_user) { create(:user_with_addresses) }

      before { get '/api/v2/storefront/account/addresses', headers: headers_bearer }

      it_behaves_like 'returns valid user addresses resource JSON'

      it 'returns all user addresses' do
        expect(json_response['data'][0]).to have_type('address')
        expect(json_response['data'].size).to eq(addresses.count)
        expect(json_response['data'].size).not_to eq Spree::Address.count
      end
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/addresses' }

      it_behaves_like 'returns 403 HTTP status'
    end

    context 'when address can not be deleted' do
      let!(:address) { create(:address, user_id: user.id) }

      before do
        expect(address).to receive(:can_be_deleted?).and_return(false).at_least(:once)
        address.destroy!
        get '/api/v2/storefront/account/addresses', headers: headers_bearer
      end

      it 'should not return deleted address' do
        expect(address.deleted_at).not_to be_nil
        expect(json_response['data'][0]).to have_type('address')
        expect(json_response['data'].size).to eq(addresses.count)
      end
    end

    context 'when address from countries that are supported in the current store' do
      let(:country) { create(:country, name: 'France') }
      let(:zone) { create(:zone, name: 'EU_VAT', countries: [country], kind: 'country') }
      let!(:eu_address) { create(:address, user_id: user.id, country: country) }

      before do
        store.update(checkout_zone: zone)
        get '/api/v2/storefront/account/addresses', headers: headers_bearer
      end

      it 'should return addresses from supported countries' do
        expect(user.addresses.size).to eq 4
        expect(json_response['data'].size).to eq 1
        expect(json_response['data'][0]).to have_attribute(:country_name).with_value(eu_address.country.name)
      end
    end

    context 'when address from countries that are not supported in the current store' do
      let(:eu_country) { create(:country, name: 'France') }
      let(:zone) { create(:zone, name: 'EU_VAT', countries: [eu_country], kind: 'country') }
      let(:country) { create(:country) }
      let!(:us_address) { create(:address, user_id: user.id, country: country) }

      before do
        store.update(checkout_zone: zone)
        get '/api/v2/storefront/account/addresses', headers: headers_bearer
      end

      it 'should not return addresses from not supported countries' do
        expect(user.addresses.size).to eq 4
        expect(json_response['data'].size).to eq 0
      end
    end

    context 'when address without user exists' do
      let!(:address) { create(:address, user_id: nil) }

      before do
        get '/api/v2/storefront/account/addresses', headers: headers_bearer
      end

      it 'should not return address without user id' do
        expect(json_response['data'][0]).to have_type('address')
        expect(json_response['data'].size).to eq(addresses.count)
      end
    end
  end

  describe 'addresses#create' do
    context 'valid request' do
      let(:new_attributes) do
        {
          firstname: 'John',
          lastname: 'Doe',
          address1: '51 Guild Street',
          address2: '2nd floor',
          city: 'London',
          phone: '079 4721 9458',
          zipcode: 'SE25 3FZ',
          state_name: 'EAW',
          country_iso: 'GBR'
        }
      end
      let(:params) { { address: new_attributes } }

      before { post '/api/v2/storefront/account/addresses', params: params, headers: headers_bearer }

      it 'creates and returns address' do
        expect(json_response['data']).to have_attribute(:firstname).with_value(new_attributes[:firstname])
        expect(json_response['data']).to have_attribute(:lastname).with_value(new_attributes[:lastname])
        expect(json_response['data']).to have_attribute(:address1).with_value(new_attributes[:address1])
        expect(json_response['data']).to have_attribute(:address2).with_value(new_attributes[:address2])
        expect(json_response['data']).to have_attribute(:city).with_value(new_attributes[:city])
        expect(json_response['data']).to have_attribute(:phone).with_value(new_attributes[:phone])
        expect(json_response['data']).to have_attribute(:zipcode).with_value(new_attributes[:zipcode])
        expect(json_response['data']).to have_attribute(:state_name).with_value(new_attributes[:state_name])
        expect(json_response['data']).to have_attribute(:country_iso).with_value(new_attributes[:country_iso])
        expect(json_response.size).to eq(1)
      end
    end

    context 'invalid request' do
      let(:new_attributes) do
        {
          firstname: 'John',
          lastname: 'Doe',
          address1: '51 Guild Street',
          address2: '2nd floor'
        }
      end
      let(:params) { { address: new_attributes } }

      before { post '/api/v2/storefront/account/addresses', params: params, headers: headers_bearer }

      it 'returns errors' do
        expect(json_response['error']).to eq("City can't be blank, Country can't be blank, Zip Code can't be blank")
        expect(json_response['errors']).to eq(
          'city' => ["can't be blank"],
          'zipcode' => ["can't be blank"],
          'country' => ["can't be blank"]
        )
      end
    end

    context 'with missing authorization token' do
      before { post '/api/v2/storefront/account/addresses' }

      it_behaves_like 'returns 403 HTTP status'
    end
  end

  describe 'addresses#update' do
    let(:address) { addresses.last }

    context 'valid request' do
      let(:new_attributes) do
        {
          firstname: 'John',
          lastname: 'Doe',
          address1: '51 Guild Street',
          address2: '2nd floor',
          city: 'London',
          phone: '079 4721 9458',
          zipcode: 'SE25 3FZ',
          state_name: state.name,
          country_iso: country.iso
        }
      end
      let(:params) { { address: new_attributes } }

      before { patch "/api/v2/storefront/account/addresses/#{address.id}", params: params, headers: headers_bearer }

      it 'updates and returns address' do
        expect(json_response['data']).to have_id(address.id.to_s)
        expect(json_response['data']).to have_attribute(:firstname).with_value(new_attributes[:firstname])
        expect(json_response['data']).to have_attribute(:lastname).with_value(new_attributes[:lastname])
        expect(json_response['data']).to have_attribute(:address1).with_value(new_attributes[:address1])
        expect(json_response['data']).to have_attribute(:address2).with_value(new_attributes[:address2])
        expect(json_response['data']).to have_attribute(:city).with_value(new_attributes[:city])
        expect(json_response['data']).to have_attribute(:phone).with_value(new_attributes[:phone])
        expect(json_response['data']).to have_attribute(:zipcode).with_value(new_attributes[:zipcode])
        expect(json_response['data']).to have_attribute(:state_name).with_value(new_attributes[:state_name])
        expect(json_response['data']).to have_attribute(:country_iso).with_value(new_attributes[:country_iso])
        expect(json_response.size).to eq(1)
      end
    end

    context 'invalid request' do
      let(:new_attributes) do
        {
          city: '',
          zipcode: ''
        }
      end
      let(:params) { { address: new_attributes } }

      before { patch "/api/v2/storefront/account/addresses/#{address.id}", params: params, headers: headers_bearer }

      it 'returns errors' do
        expect(json_response['error']).to eq("City can't be blank, Zip Code can't be blank")
        expect(json_response['errors']).to eq(
          'city' => ["can't be blank"],
          'zipcode' => ["can't be blank"]
        )
      end
    end

    context 'with missing authorization token' do
      before { patch "/api/v2/storefront/account/addresses/#{address.id}" }

      it_behaves_like 'returns 403 HTTP status'
    end
  end

  describe 'addresses#destroy' do
    let(:address) { addresses.last }

    context 'valid request' do
      before { delete "/api/v2/storefront/account/addresses/#{address.id}", headers: headers_bearer }

      it 'destroys address permanently' do
        expect { Spree::Address.unscoped.find(address.id) }.to raise_exception(ActiveRecord::RecordNotFound)
        expect { address.reload }.to raise_exception(ActiveRecord::RecordNotFound)
      end
    end

    context 'valid request with existing shipment' do
      let!(:order) { create :completed_order_with_totals, ship_address: address, bill_address: address}

      before {
        delete "/api/v2/storefront/account/addresses/#{address.id}", headers: headers_bearer
        address.reload
      }

      it 'sets deleted_at date for address' do
        expect(address.deleted_at).not_to be_nil
      end
    end

    context 'with missing authorization token' do
      before { delete "/api/v2/storefront/account/addresses/#{address.id}" }

      it_behaves_like 'returns 403 HTTP status'
    end
  end
end
