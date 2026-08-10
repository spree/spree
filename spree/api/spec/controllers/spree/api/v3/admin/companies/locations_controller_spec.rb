require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Companies::LocationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the branches of the company' do
      create(:company_location, company: company, name: 'Berlin')

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('cloc_')
      expect(row['name']).to eq('Berlin')
      expect(row['company_id']).to eq(company.prefixed_id)
    end

    it '404s under another store company' do
      get :index, params: { company_id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:germany) { create(:country, iso: 'DE', name: 'Germany') }

    it 'creates a branch' do
      post :create, params: { company_id: company.prefixed_id, name: 'Hamburg' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Hamburg')
      expect(company.company_locations.count).to eq(1)
    end

    # The branch owns its address rather than pointing at a shared row.
    it 'creates the addresses inline' do
      post :create, params: {
        company_id: company.prefixed_id,
        name: 'Munich',
        billing_address: {
          first_name: 'Anna', last_name: 'Muller', address1: 'Leopoldstr 1',
          city: 'Munich', postal_code: '80802', country_iso: germany.iso
        }
      }, as: :json

      expect(response).to have_http_status(:created)
      location = company.company_locations.sole
      expect(location.billing_address.city).to eq('Munich')
      expect(json_response['billing_address']['city']).to eq('Munich')
    end

    it 'rejects a branch with no name' do
      post :create, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
