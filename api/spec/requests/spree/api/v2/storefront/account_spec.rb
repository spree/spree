require 'spec_helper'

describe 'Storefront API v2 Account spec', type: :request do
  include_context 'API v2 tokens'

  let!(:user)  { create(:user_with_addresses) }
  let(:headers) { headers_bearer }

  describe 'account#show' do
    before { get '/api/v2/storefront/account', headers: headers }

    it_behaves_like 'returns 200 HTTP status'

    it 'return JSON API payload of User and associations (default billing and shipping address)' do
      expect(json_response['data']).to have_id(user.id.to_s)
      expect(json_response['data']).to have_type('user')
      expect(json_response['data']).to have_relationships(:default_shipping_address, :default_billing_address)

      expect(json_response['data']).to have_attribute(:email).with_value(user.email)
      expect(json_response['data']).to have_attribute(:store_credits).with_value(user.total_available_store_credit)
      expect(json_response['data']).to have_attribute(:completed_orders).with_value(user.orders.complete.count)
    end

    context 'with params "include=default_billing_address"' do
      before { get '/api/v2/storefront/account?include=default_billing_address', headers: headers }

      it 'returns account data with included default billing address' do
        expect(json_response['included']).to    include(have_type('address'))
        expect(json_response['included'][0]).to eq(Spree::V2::Storefront::AddressSerializer.new(user.billing_address).as_json['data'])
      end
    end

    context 'with params "include=default_shipping_address"' do
      before { get '/api/v2/storefront/account?include=default_shipping_address', headers: headers }

      it 'returns account data with included default shipping address' do
        expect(json_response['included']).to    include(have_type('address'))
        expect(json_response['included'][0]).to eq(Spree::V2::Storefront::AddressSerializer.new(user.shipping_address).as_json['data'])
      end
    end

    context 'with params include=default_billing_address,default_shipping_address' do
      before { get '/api/v2/storefront/account?include=default_billing_address,default_shipping_address', headers: headers }

      it 'returns account data with included default billing and shipping addresses' do
        expect(json_response['included']).to    include(have_type('address'))
        expect(json_response['included'][0]).to eq(Spree::V2::Storefront::AddressSerializer.new(user.billing_address).as_json['data'])
        expect(json_response['included'][1]).to eq(Spree::V2::Storefront::AddressSerializer.new(user.shipping_address).as_json['data'])
      end
    end

    context 'as a guest user' do
      let(:headers) { {} }

      it_behaves_like 'returns 403 HTTP status'
    end
  end

  describe 'users#create' do
    let(:default_bill_address) { create(:address) }
    let(:default_ship_address) { create(:address) }
    let(:new_attributes) do
      {
        email: 'new@email.com',
        password: 'newpassword123',
        password_confirmation: 'newpassword123',
        bill_address_id: default_bill_address.id,
        ship_address_id: default_ship_address.id
      }
    end
    let(:params) { { user: new_attributes } }

    before { post "/api/v2/storefront/account", params: params }

    context 'valid request' do
      it_behaves_like 'returns 200 HTTP status'

      it 'updates and returns user' do
        expect(json_response['data']['id'].to_i).to eq Spree.user_class.last.id
        expect(json_response['data']).to have_attribute(:email).with_value(new_attributes[:email])
        expect(json_response.size).to eq(1)
      end

      it 'does not create user default bill_address and ship_address' do
        expect(json_response['data']['relationships']['default_billing_address']).to eq ({ "data" => nil })
        expect(json_response['data']['relationships']['default_shipping_address']).to eq ({ "data" => nil })
      end
    end
  end

  describe 'users#update' do
    let(:new_attributes) do
      {
        email: 'new@email.com',
        password: 'newpassword123',
        password_confirmation: 'newpassword123',
        bill_address_id: new_default_bill_address.id,
        ship_address_id: new_default_ship_address.id
      }
    end
    let(:params) { { user: new_attributes } }

    context 'valid request' do
      let(:new_default_bill_address) { create(:address, user: user) }
      let(:new_default_ship_address) { create(:address, user: user) }

      before { patch "/api/v2/storefront/account", params: params, headers: headers }

      it_behaves_like 'returns 200 HTTP status'

      it 'updates and returns user' do
        expect(json_response['data']).to have_id(user.id.to_s)
        expect(json_response['data']).to have_attribute(:email).with_value(new_attributes[:email])
        expect(json_response['data']).to have_relationship(:default_billing_address)
                                           .with_data({ 'id' => new_default_bill_address.id.to_s, 'type' => 'address' })
        expect(json_response['data']).to have_relationship(:default_shipping_address)
                                           .with_data({ 'id' => new_default_ship_address.id.to_s, 'type' => 'address' })
        expect(json_response.size).to eq(1)
      end
    end

    context 'invalid request' do
      let!(:other_user) { create(:user_with_addresses) }
      let(:new_default_bill_address) { create(:address, user: other_user) }
      let(:new_default_ship_address) { create(:address, user: other_user) }

      before { patch "/api/v2/storefront/account", params: params, headers: headers }

      it 'returns errors' do
        expect(json_response['errors']).to eq(
                                              'bill_address_id' => ["belongs to other user"],
                                              'ship_address_id' => ["belongs to other user"]
                                             )
      end
    end

    context 'with missing authorization token' do
      let(:new_default_bill_address) { create(:address, user: user) }
      let(:new_default_ship_address) { create(:address, user: user) }

      before { patch "/api/v2/storefront/account", params: params }

      it_behaves_like 'returns 403 HTTP status'
    end
  end
end
