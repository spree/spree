require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Customer::TaxIdentifiersController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:eu) { create(:tax_identifier, customer: user, kind: 'eu_vat', value: 'DE123456789') }
  let!(:gb) { create(:tax_identifier, customer: user, kind: 'gb_vat', value: 'GB123456789') }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'GET #index' do
    # What a checkout page needs to offer the buyer a choice: a business
    # registered under two regimes has two, and asking by kind means guessing.
    it 'lists every registration the buyer holds' do
      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |row| row['kind'] }).to contain_exactly('eu_vat', 'gb_vat')
      expect(json_response['data'].map { |row| row['value'] }).to contain_exactly('DE123456789', 'GB123456789')
    end

    it 'lists nobody else\'s' do
      create(:tax_identifier, customer: create(:user), kind: 'eu_vat', value: 'FR999999999')

      get :index

      expect(json_response['data'].map { |row| row['value'] }).not_to include('FR999999999')
    end

    it 'returns an empty list for a buyer with none' do
      Spree::TaxIdentifier.where(customer_id: user.id).destroy_all

      get :index

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to eq([])
    end

    it 'refuses an unauthenticated request' do
      request.headers['Authorization'] = nil

      get :index

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #show' do
    it 'returns the registration of the requested kind' do
      get :show, params: { kind: 'gb_vat' }

      expect(response).to have_http_status(:ok)
      expect(json_response['value']).to eq('GB123456789')
    end
  end
end
