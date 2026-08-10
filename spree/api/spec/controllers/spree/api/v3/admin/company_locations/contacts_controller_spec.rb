require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CompanyLocations::ContactsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }
  let!(:location) { create(:company_location, company: company) }
  let!(:customer) { create(:customer, email: 'buyer@acme.test') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists who buys for the branch' do
      create(:company_contact, company_location: location, customer: customer)

      get :index, params: { company_location_id: location.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('cc_')
      expect(row['email']).to eq('buyer@acme.test')
      expect(row['role']).to eq('buyer')
      expect(row['customer_id']).to eq(customer.prefixed_id)
    end

    it '404s under a branch of another store company' do
      elsewhere = create(:company_location, company: create(:company, store: create(:store)))

      get :index, params: { company_location_id: elsewhere.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'authorises a customer to buy for the branch' do
      post :create, params: {
        company_location_id: location.prefixed_id,
        customer_id: customer.prefixed_id,
        role: 'admin'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['role']).to eq('admin')
      expect(location.customers).to eq([customer])
    end

    it 'refuses the same customer twice on one branch' do
      create(:company_contact, company_location: location, customer: customer)

      post :create, params: { company_location_id: location.prefixed_id, customer_id: customer.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
