require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::TaxExemptionReasonsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:reason) { create(:tax_exemption_reason, name: 'Reseller (wholesale)', code: 'G') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the store reasons with their codes' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to include(include('id' => reason.prefixed_id, 'code' => 'G'))
    end

    it 'excludes another store\'s reasons' do
      other = create(:tax_exemption_reason, store: create(:store))

      get :index, as: :json

      expect(json_response['data'].map { |r| r['id'] }).not_to include(other.prefixed_id)
    end
  end

  describe 'POST #create' do
    it 'creates a reason' do
      expect { post :create, params: { name: 'Federal government', code: 'A' }, as: :json }.
        to change(store.tax_exemption_reasons, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response).to include('name' => 'Federal government', 'code' => 'A', 'active' => true)
    end

    it 'rejects a code the store already uses' do
      post :create, params: { name: 'Another resale', code: 'G' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'renames the reason' do
      patch :update, params: { id: reason.prefixed_id, name: 'Resale' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(reason.reload.name).to eq('Resale')
    end

    # Certificates hold the code, not a reference, so changing it would strand them.
    it 'refuses to change a code a certificate records' do
      create(:tax_exemption_certificate, company: create(:company, store: store), reason_code: 'G')

      patch :update, params: { id: reason.prefixed_id, code: 'N' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(reason.reload.code).to eq('G')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes an unused reason' do
      expect { delete :destroy, params: { id: reason.prefixed_id }, as: :json }.
        to change(Spree::TaxExemptionReason, :count).by(-1)
    end

    it 'refuses to delete a reason a certificate records' do
      create(:tax_exemption_certificate, company: create(:company, store: store), reason_code: 'G')

      expect { delete :destroy, params: { id: reason.prefixed_id }, as: :json }.
        not_to change(Spree::TaxExemptionReason, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
