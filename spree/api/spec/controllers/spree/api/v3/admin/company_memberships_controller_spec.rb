require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CompanyMembershipsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:company) { create(:company, store: store) }
  let!(:membership) { create(:company_membership, company: company) }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    it 'returns the membership' do
      get :show, params: { id: membership.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(membership.prefixed_id)
    end

    it '404s a membership of another store company' do
      foreign = create(:company_membership, company: create(:company, store: create(:store)))

      get :show, params: { id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'removes the standing' do
      delete :destroy, params: { id: membership.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(company.memberships.reload).to be_empty
    end
  end
end
