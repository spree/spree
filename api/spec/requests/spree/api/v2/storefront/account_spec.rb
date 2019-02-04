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
end
