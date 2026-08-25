require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CompanyAddressesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:company) { create(:company, store: store) }
  let!(:entry) { create(:company_address, company: company, label: 'HQ') }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    it 'returns the entry with its address' do
      get :show, params: { id: entry.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['label']).to eq('HQ')
      expect(json_response['company_id']).to eq(company.prefixed_id)
    end

    it '404s an entry of another store company' do
      foreign = create(:company_address, company: create(:company, store: create(:store)))

      get :show, params: { id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH #update' do
    it 'edits the address in place instead of replacing it' do
      original_address_id = entry.address_id

      patch :update, params: { id: entry.prefixed_id, address: { city: 'Shelbyville' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(entry.reload.address_id).to eq(original_address_id)
      expect(entry.address.city).to eq('Shelbyville')
    end

    it 'promotes an entry to default billing' do
      patch :update, params: { id: entry.prefixed_id, default_billing: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(entry.reload.default_billing).to be(true)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the entry and its owned address row' do
      expect {
        delete :destroy, params: { id: entry.prefixed_id }, as: :json
      }.to change(Spree::Address, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
