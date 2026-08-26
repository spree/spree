require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Companies::AddressesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the node address book' do
      entry = create(:company_address, owner: company, label: 'HQ')

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to eq(entry.prefixed_id)
      expect(row['label']).to eq('HQ')
      expect(row['address1']).to be_present
    end

    it '404s under another store company' do
      get :index, params: { company_id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates an owned address with a label and defaults' do
      post :create, params: {
        company_id: company.prefixed_id,
        label: 'Plant 2 dock',
        default_shipping: true,
        first_name: 'Ops', last_name: 'Team', address1: '1 Dock Rd',
        city: 'Springfield', postal_code: '62704', country_code: 'US', state_code: 'IL'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['label']).to eq('Plant 2 dock')
      expect(json_response['default_shipping']).to be(true)
      expect(company.addresses.sole.city).to eq('Springfield')
      expect(company.reload.default_ship_address_id).to eq(company.addresses.sole.id)
    end

    # The node points at one address per kind, so promoting a new entry moves
    # the pointer — there is no previous flag left to contradict it.
    it 'moves the default to the new entry' do
      previous = create(:company_address, owner: company)
      company.update!(default_ship_address: previous)

      post :create, params: {
        company_id: company.prefixed_id,
        default_shipping: true,
        first_name: 'A', last_name: 'B', address1: '2 Way', city: 'Metropolis',
        postal_code: '10001', country_code: 'US', state_code: 'NY'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(company.reload.default_ship_address_id).not_to eq(previous.id)
      expect(json_response['default_shipping']).to be(true)
    end

    # A company address names no person: the node names itself.
    it 'accepts an entry with no contact name' do
      post :create, params: {
        company_id: company.prefixed_id,
        label: 'Warehouse',
        address1: '9 Depot Way', city: 'Springfield',
        postal_code: '62704', country_code: 'US', state_code: 'IL'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(company.addresses.sole.first_name).to be_blank
    end
  end
end
