require 'spec_helper'

describe 'Storefront API v2 Account spec', type: :request do
  include_context 'API v2 tokens'

  let!(:user)  { create(:user_with_addresses) }
  let(:headers) { headers_bearer }

  shared_examples 'mock tests for failed user saving' do
    it { expect(service).to receive(:call).with(permitted_params).and_return(result) }
    it { expect(result).to receive(:success?).and_return(false) }
    it { expect(result).to receive(:error).and_return(error) }
    it { expect(error).to receive_message_chain(:full_messages, :to_sentence).and_return("Password Confirmation doesn't match Password") }
  end

  shared_context 'stubs for failed user saving' do
    before do
      allow(service).to receive(:call).with(permitted_params).and_return(result)
      allow(result).to receive(:success?).and_return(false)
      allow(result).to receive(:error).and_return(error)
      allow(error).to receive(:is_a?).with(ActiveModel::Errors).and_return(true)
      allow(error).to receive(:messages).and_return({ password_confirmation: "doesn't match Password" })
      allow(error).to receive_message_chain(:full_messages, :to_sentence).and_return("Password Confirmation doesn't match Password")
    end
  end

  shared_examples 'password mismatched error' do
    it 'returns error' do
      expect(json_response['error']).to eq "Password Confirmation doesn't match Password"
    end
  end

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

      it 'creates and returns user' do
        expect(json_response['data']['id'].to_i).to eq Spree.user_class.last.id
        expect(json_response['data']).to have_attribute(:email).with_value(new_attributes[:email])
        expect(json_response.size).to eq(1)
      end

      it 'does not create user default bill_address and ship_address' do
        expect(json_response['data']['relationships']['default_billing_address']).to eq ({ "data" => nil })
        expect(json_response['data']['relationships']['default_shipping_address']).to eq ({ "data" => nil })
      end
    end

    context 'invalid request' do
      let(:new_attributes) do
        {
          email: 'new@email.com',
          password: 'newpassword123',
          password_confirmation: ''
        }
      end
      let(:service) { double(Spree::Account::Create) }
      let(:permitted_params) { {user_params: ActionController::Parameters.new(params).require(:user).permit!} }
      let(:result) { instance_double(Spree::ServiceModule::Result) }
      let(:error) { instance_double(ActiveModel::Errors) }

      before do
        allow(Spree::Api::Dependencies).to receive_message_chain(:storefront_account_create_service, :constantize).and_return(service)
      end

      include_context 'stubs for failed user saving'

      describe 'mocks' do
        after { post "/api/v2/storefront/account", params: params }

        it { expect(Spree::Api::Dependencies).to receive_message_chain(:storefront_account_create_service, :constantize).and_return(service) }

        it_behaves_like 'mock tests for failed user saving'
      end

      describe 'response' do
        before { post "/api/v2/storefront/account", params: params }

        it_behaves_like 'password mismatched error'
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
      context 'all params passed' do
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

      context 'with only email passed' do
        let(:new_attributes) do
          {
            email: 'new@email.com'
          }
        end

        before { patch "/api/v2/storefront/account", params: params, headers: headers }

        it_behaves_like 'returns 200 HTTP status'

        it 'updates only email' do
          expect(json_response['data']).to have_id(user.id.to_s)
          expect(json_response['data']).to have_attribute(:email).with_value(new_attributes[:email])
          expect(json_response['data']).to have_relationship(:default_billing_address)
                                             .with_data({ 'id' => user.bill_address_id.to_s, 'type' => 'address' })
          expect(json_response['data']).to have_relationship(:default_shipping_address)
                                             .with_data({ 'id' => user.ship_address_id.to_s, 'type' => 'address' })
          expect(json_response.size).to eq(1)
        end
      end
    end

    context 'invalid request' do
      context 'wrong default address' do
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

      context 'password mismatch error' do
        let(:new_attributes) do
          {
            email: 'new@email.com',
            password: 'newpassword123',
            password_confirmation: ''
          }
        end
        let(:service) { double(Spree::Account::Update) }
        let(:permitted_params) { { user_params: ActionController::Parameters.new(params).require(:user).permit!, user: user } }
        let(:result) { instance_double(Spree::ServiceModule::Result) }
        let(:error) { instance_double(ActiveModel::Errors) }

        before do
          allow(Spree::Api::Dependencies).to receive_message_chain(:storefront_account_update_service, :constantize).and_return(service)
        end

        include_context 'stubs for failed user saving'

        describe 'mocks' do
          after { patch "/api/v2/storefront/account", params: params, headers: headers }

          it { expect(Spree::Api::Dependencies).to receive_message_chain(:storefront_account_update_service, :constantize).and_return(service) }

          it_behaves_like 'mock tests for failed user saving'
        end

        describe 'response' do
          before { patch "/api/v2/storefront/account", params: params, headers: headers }

          it_behaves_like 'password mismatched error'
        end
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
