require 'spec_helper'
require 'shared_examples/api_v2/base'

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

    context 'as a guest user' do
      let(:headers) { {} }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
