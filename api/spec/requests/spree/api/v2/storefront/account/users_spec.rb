require 'spec_helper'

describe 'Storefront API v2 User spec', type: :request do
  include_context 'API v2 tokens'

  let!(:user)  { create(:user_with_addresses) }
  let(:headers) { headers_bearer }

  describe 'users#update' do
    context 'valid request' do
      let(:new_default_bill_address) { create(:address, user: user) }
      let(:new_default_ship_address) { create(:address, user: user) }

      let(:new_attributes) do
        {
          bill_address_id: new_default_bill_address.id,
          ship_address_id: new_default_ship_address.id
        }
      end
      let(:params) { { user: new_attributes } }

      before { patch "/api/v2/storefront/account/users/#{user.id}", params: params, headers: headers }

      it_behaves_like 'returns 200 HTTP status'

      it 'updates and returns address' do
        expect(json_response['data']).to have_id(user.id.to_s)
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

      let(:new_attributes) do
        {
          bill_address_id: new_default_bill_address.id,
          ship_address_id: new_default_ship_address.id
        }
      end
      let(:params) { { user: new_attributes } }

      before { patch "/api/v2/storefront/account/users/#{user.id}", params: params, headers: headers }

      it 'returns errors' do
        expect(json_response['errors']).to eq(
                                              'bill_address_id' => ["belongs to other user"],
                                              'ship_address_id' => ["belongs to other user"]
                                             )
      end
    end

    context 'with missing authorization token' do
      before { patch "/api/v2/storefront/account/users/#{user.id}" }

      it_behaves_like 'returns 403 HTTP status'
    end
  end
end
