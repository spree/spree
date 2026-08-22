require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CompaniesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) do
    create(:company, store: store, name: 'Acme Industrial').tap { |record| record.set_external_id('erp', 'ACME-1') }
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the store companies' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].first
      expect(row['id']).to start_with('comp_')
      expect(row['name']).to eq('Acme Industrial')
      expect(row['external_references']).to eq('erp' => 'ACME-1')
    end

    it 'hides companies belonging to another store' do
      other = create(:company, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |row| row['id'] }).not_to include(other.prefixed_id)
    end

    it 'counts branches without a request per row' do
      create(:company_location, company: company)

      get :index, as: :json

      expect(json_response['data'].first['locations_count']).to eq(1)
    end
  end

  describe 'GET #show' do
    it 'expands branches on request' do
      location = create(:company_location, company: company, name: 'Berlin')

      get :show, params: { id: company.prefixed_id, expand: 'company_locations' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['company_locations'].first['name']).to eq('Berlin')
      expect(json_response['company_locations'].first['id']).to eq(location.prefixed_id)
    end

    it '404s for another store company' do
      get :show, params: { id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a company bound to the current store' do
      post :create, params: { name: 'Globex' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Globex')
      expect(Spree::Company.find_by(name: 'Globex').store).to eq(store)
    end

    it 'records the external identity the connector sent' do
      post :create, params: { name: 'Globex', external_references: [{ system: 'erp', external_id: 'GLBX' }] }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['external_references']).to eq('erp' => 'GLBX')
      expect(Spree::Company.find_by(name: 'Globex').external_id_for('erp')).to eq('GLBX')
    end

    it 'updates the existing record when the external id is already known' do
      expect do
        post :create, params: { name: 'Acme Renamed', external_references: [{ system: 'erp', external_id: 'ACME-1' }] },
                      as: :json
      end.not_to change(Spree::Company, :count)

      expect(company.reload.name).to eq('Acme Renamed')
    end

    it 'rejects a company with no name' do
      post :create, params: {}, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'renames a company' do
      patch :update, params: { id: company.prefixed_id, name: 'Acme Global' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(company.reload.name).to eq('Acme Global')
    end

    it 'addresses the company by the identity the external system knows' do
      patch :update, params: { id: 'external:erp:ACME-1', name: 'Acme Via ERP' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(company.reload.name).to eq('Acme Via ERP')
    end

    it 'leaves other systems alone when one connector writes its key' do
      company.set_external_id('crm', 'CUST-9')

      patch :update, params: { id: company.prefixed_id,
                               external_references: [{ system: 'erp', external_id: 'ACME-2' }] }, as: :json

      expect(company.reload.external_id_for('erp')).to eq('ACME-2')
      expect(company.external_id_for('crm')).to eq('CUST-9')
    end

    it 'does not reach a company in another store through its external id' do
      other = create(:company, store: create(:store))
      other.set_external_id('erp', 'OTHER-1')

      patch :update, params: { id: 'external:erp:OTHER-1', name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other.reload.name).not_to eq('Hijacked')
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the company and its branches' do
      create(:company_location, company: company)

      delete :destroy, params: { id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Company.where(id: company.id)).to be_empty
      expect(Spree::CompanyLocation.count).to eq(0)
    end
  end
end
