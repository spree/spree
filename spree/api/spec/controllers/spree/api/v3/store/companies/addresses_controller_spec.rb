require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Companies::AddressesController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store) }

  before do
    create(:company_membership, company: company, customer: user)
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    it 'lists the node address book' do
      create(:company_address, company: company, label: 'HQ')

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].sole['label']).to eq('HQ')
    end

    it '404s a node without standing' do
      get :index, params: { company_id: create(:company, store: store).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates an entry with a nested address' do
      post :create, params: {
        company_id: company.prefixed_id,
        label: 'Plant 2 dock', default_shipping: true,
        address: { first_name: 'Ops', last_name: 'Team', address1: '1 Dock Rd',
                   city: 'Springfield', postal_code: '62704', country_code: 'US', state_code: 'IL' }
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['label']).to eq('Plant 2 dock')
      expect(json_response['default_shipping']).to be(true)
      expect(json_response['address']['city']).to eq('Springfield')
    end
  end
end
