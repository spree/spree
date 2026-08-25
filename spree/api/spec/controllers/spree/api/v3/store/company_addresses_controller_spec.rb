require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CompanyAddressesController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store) }
  let!(:entry) { create(:company_address, company: company, label: 'HQ') }

  before { request.headers.merge!(headers) }

  context 'with standing' do
    before { create(:company_membership, company: company, customer: user) }

    it 'edits the entry, keeping the address row' do
      original_address_id = entry.address_id

      patch :update, params: { id: entry.prefixed_id, label: 'Head office', address: { city: 'Shelbyville' } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(entry.reload.label).to eq('Head office')
      expect(entry.address_id).to eq(original_address_id)
      expect(entry.address.city).to eq('Shelbyville')
    end

    it 'removes the entry and its owned address row' do
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
