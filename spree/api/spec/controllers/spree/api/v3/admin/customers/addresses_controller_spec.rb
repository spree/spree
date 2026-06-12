require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Customers::AddressesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:customer) { create(:user) }
  let!(:address) { create(:address, user: customer) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the customer addresses' do
      get :index, params: { customer_id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |a| a['id'] }).to include(address.prefixed_id)
    end

    # Broken object-level authorization: the nested index must enforce the
    # caller's ability on the parent customer. A customer the caller can't view
    # is filtered out of the ability-scoped lookup, so it 404s rather than
    # leaking its existence as a 403.
    context 'with a limited-role admin that cannot read customers' do
      include_context 'API v3 Admin with custom permissions'

      let(:custom_permission_set) do
        Class.new(Spree::PermissionSets::Base) do
          def activate!
            can [:read, :admin], Spree::Product
          end
        end
      end

      it 'cannot read another customer\'s addresses' do
        get :index, params: { customer_id: customer.prefixed_id }, as: :json

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST #create' do
    let(:state) { create(:state) }
    let(:country) { state.country }
    let(:create_params) do
      {
        customer_id: customer.prefixed_id,
        firstname: 'Jane',
        lastname: 'Doe',
        address1: '123 Main St',
        city: 'Brooklyn',
        zipcode: '11201',
        country_id: country.id,
        state_id: state.id,
        phone: '+15551234567'
      }
    end

    it 'creates a new address for the customer' do
      expect { post :create, params: create_params, as: :json }.to change(customer.addresses, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['address1']).to eq('123 Main St')
    end

    context 'with is_default_billing flag' do
      it 'sets the customer default billing address' do
        post :create, params: create_params.merge(is_default_billing: true), as: :json

        expect(response).to have_http_status(:created)
        new_id = Spree::Address.find_by_prefix_id(json_response['id']).id
        expect(customer.reload.bill_address_id).to eq(new_id)
      end
    end

    context 'with is_default_shipping flag' do
      it 'sets the customer default shipping address' do
        post :create, params: create_params.merge(is_default_shipping: true), as: :json

        expect(response).to have_http_status(:created)
        new_id = Spree::Address.find_by_prefix_id(json_response['id']).id
        expect(customer.reload.ship_address_id).to eq(new_id)
      end
    end
  end

  describe 'PATCH #update' do
    it 'updates the address' do
      patch :update, params: { customer_id: customer.prefixed_id, id: address.prefixed_id, city: 'NewCity' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['city']).to eq('NewCity')
    end

    it 'rotates the default billing flag' do
      other = create(:address, user: customer)
      customer.update!(bill_address_id: other.id)
      target_id = address.id

      patch :update, params: { customer_id: customer.prefixed_id, id: address.prefixed_id, is_default_billing: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(customer.reload.bill_address_id).to eq(target_id)
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys the address when not referenced by completed orders' do
      delete :destroy, params: { customer_id: customer.prefixed_id, id: address.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Address.where(id: address.id)).to be_empty
    end
  end
end
