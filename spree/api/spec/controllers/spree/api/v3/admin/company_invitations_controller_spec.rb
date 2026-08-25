require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CompanyInvitationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:company) { create(:company, store: store) }
  let!(:invitation) { create(:company_invitation, company: company) }

  before { request.headers.merge!(headers) }

  describe 'GET #show' do
    it 'returns the invitation without its token' do
      get :show, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('pending')
      expect(json_response).not_to have_key('token')
    end
  end

  describe 'DELETE #destroy' do
    it 'revokes rather than erases' do
      delete :destroy, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(invitation.reload).to be_revoked
    end

    it 'refuses on an already spent invitation' do
      invitation.update!(accepted_at: Time.current)

      delete :destroy, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '404s an invitation of another store company' do
      foreign = create(:company_invitation, company: create(:company, store: create(:store)))

      delete :destroy, params: { id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
