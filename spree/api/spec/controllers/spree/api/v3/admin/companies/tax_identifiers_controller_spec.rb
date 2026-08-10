require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Companies::TaxIdentifiersController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the business registrations' do
      create(:tax_identifier, customer: nil, company: company, kind: 'eu_vat', value: 'DE123456789')

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('txi_')
      expect(row['kind']).to eq('eu_vat')
      expect(row['value']).to eq('DE123456789')
    end

    it '404s under another store company' do
      get :index, params: { company_id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    # Phase 3 made a business registration outrank the buyer's; without this
    # endpoint that behaviour was only reachable from a console.
    it 'registers a number against the business' do
      post :create, params: { company_id: company.prefixed_id, kind: 'eu_vat', value: 'DE123456789' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['value']).to eq('DE123456789')
      expect(company.tax_identifiers.sole.kind).to eq('eu_vat')
    end

    it 'takes effect on a sale for that business' do
      create(:tax_identifier, customer: nil, company: company, kind: 'eu_vat', value: 'DE222222222')
      location = create(:company_location, company: company)
      customer = create(:customer)
      create(:tax_identifier, customer: customer, kind: 'eu_vat', value: 'DE111111111')
      cart = create(:cart, store: store, customer: customer, company_location: location)

      expect(cart.resolved_tax_identifier.value).to eq('DE222222222')
    end

    it 'holds one registration per kind' do
      create(:tax_identifier, customer: nil, company: company, kind: 'eu_vat', value: 'DE123456789')

      post :create, params: { company_id: company.prefixed_id, kind: 'eu_vat', value: 'DE999999999' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'requires a kind and a value' do
      post :create, params: { company_id: company.prefixed_id, kind: 'eu_vat' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    # Format is only checked when a validator is registered for the kind; a
    # stock install registers none, so anything well-formed enough is accepted.
    it 'checks the format when a validator is installed' do
      validator = Class.new(Spree::TaxIdentifiers::Validator::Base) do
        def self.valid_format?(value) = value.to_s.start_with?('DE')
      end
      stub_const('SpecEuVatValidator', validator)
      Spree.tax_identifier_validators['eu_vat'] = 'SpecEuVatValidator'

      post :create, params: { company_id: company.prefixed_id, kind: 'eu_vat', value: '!!' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    ensure
      Spree.tax_identifier_validators.delete('eu_vat')
    end
  end

  describe 'PATCH #update' do
    it 'corrects the number' do
      identifier = create(:tax_identifier, customer: nil, company: company, kind: 'eu_vat', value: 'DE123456789')

      patch :update, params: { company_id: company.prefixed_id, id: identifier.prefixed_id, value: 'DE987654321' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(identifier.reload.value).to eq('DE987654321')
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the registration' do
      identifier = create(:tax_identifier, customer: nil, company: company, kind: 'eu_vat')

      delete :destroy, params: { company_id: company.prefixed_id, id: identifier.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(company.tax_identifiers.reload).to be_empty
    end
  end

  describe 'POST #validate' do
    it 'reports when no validator is installed for the kind' do
      identifier = create(:tax_identifier, customer: nil, company: company, kind: 'eu_vat')

      post :validate, params: { company_id: company.prefixed_id, id: identifier.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('tax_id_not_validatable')
    end
  end
end
