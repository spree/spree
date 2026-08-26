require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Account::CompaniesController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists my memberships with each node and its ancestor path' do
      root = create(:company, store: store, name: 'Acme')
      division = create(:company, store: store, kind: 'division', parent: root, name: 'EMEA')
      membership = create(:company_membership, company: division, customer: user)

      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].sole
      expect(row['id']).to eq(membership.prefixed_id)
      expect(row['company']['id']).to eq(division.prefixed_id)
      expect(row['company']['name']).to eq('EMEA')
      expect(row['company']['ancestors'].map { |a| a['name'] }).to eq(['Acme'])
    end

    it 'hides memberships at companies of another store' do
      create(:company_membership, company: create(:company, store: create(:store)), customer: user)

      get :index, as: :json

      expect(json_response['data']).to be_empty
    end

    it '401s a guest' do
      request.headers['Authorization'] = nil

      get :index, as: :json

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
