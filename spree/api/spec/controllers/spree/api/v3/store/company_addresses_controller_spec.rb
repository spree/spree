require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CompanyAddressesController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store) }
  let!(:entry) { create(:company_address, owner: company, label: 'HQ') }

  before { request.headers.merge!(headers) }

  context 'with standing' do
    before { create(:company_membership, company: company, customer: user) }

    it 'edits the entry in place' do
      patch :update, params: { id: entry.prefixed_id, label: 'Head office', city: 'Shelbyville' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(entry.reload.label).to eq('Head office')
      expect(entry.city).to eq('Shelbyville')
    end

    it 'removes the owned address row' do
      expect {
        delete :destroy, params: { id: entry.prefixed_id }, as: :json
      }.to change(Spree::Address, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  it '404s without standing' do
    patch :update, params: { id: entry.prefixed_id, label: 'X' }, as: :json

    expect(response).to have_http_status(:not_found)
  end
end
