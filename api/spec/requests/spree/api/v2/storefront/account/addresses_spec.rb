require 'spec_helper'

describe 'Storefront API v2 Addresses spec', type: :request do
  let!(:user) { create(:user) }
  let!(:params) { { user_id: user.id } }
  let!(:addresses) { create_list(:address, 3, user_id: user.id) }
  let!(:country) { create(:country, iso: 'GBR') }
  let!(:state) { create(:state, country: country) }

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
    end
  end

  include_context 'API v2 tokens'

  describe 'addresses#index' do
    context 'without options' do
      before { get '/api/v2/storefront/account/addresses', headers: headers_bearer }

      it_behaves_like 'returns valid user addresses resource JSON'

      it 'returns all user addresses' do
        expect(json_response['data'][0]).to have_type('address')
        expect(json_response['data'].size).to eq(addresses.count)
      end
    end

    context 'with missing authorization token' do
      before { get '/api/v2/storefront/account/addresses' }

      it_behaves_like 'returns 403 HTTP status'
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
        expect(json_response['error']).to eq("City can't be blank, Country can't be blank, Zip Code can't be blank, Phone can't be blank")
        expect(json_response['errors']).to eq(
          'city' => ["can't be blank"],
          'zipcode' => ["can't be blank"],
          'country' => ["can't be blank"],
          'phone' => ["can't be blank"]
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
end
