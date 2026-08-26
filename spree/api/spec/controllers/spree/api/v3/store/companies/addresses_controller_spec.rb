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
      create(:company_address, owner: company, label: 'HQ')

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
    it 'creates an owned address for the node' do
      post :create, params: {
        company_id: company.prefixed_id,
        label: 'Plant 2 dock', default_shipping: true,
        first_name: 'Ops', last_name: 'Team', address1: '1 Dock Rd',
        city: 'Springfield', postal_code: '62704', country_code: 'US', state_code: 'IL'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['label']).to eq('Plant 2 dock')
      expect(json_response['is_default_shipping']).to be(true)
      expect(json_response['city']).to eq('Springfield')
      expect(company.reload.default_ship_address_id).to eq(company.addresses.sole.id)
    end
  end
  # A division ships to what it inherits, so its book shows the ancestors'
  # sites as well as its own — the chain checkout accepts an id from.
  describe 'GET #index for a division' do
    it 'includes the addresses it inherits from its ancestors' do
      division = create(:company, store: store, kind: 'division', parent: company)
      inherited = create(:company_address, owner: company, label: 'Headquarters')
      own = create(:company_address, owner: division, label: 'Dock 4')

      get :index, params: { company_id: division.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['id'] }).
        to contain_exactly(own.prefixed_id, inherited.prefixed_id)
    end
  end
end
