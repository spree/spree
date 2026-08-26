require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Companies::InvitationsController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the node invitations for a member' do
      create(:company_membership, company: company, customer: user)
      invitation = create(:company_invitation, company: company)

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      row = json_response['data'].sole
      expect(row['id']).to eq(invitation.prefixed_id)
      expect(row['status']).to eq('pending')
      expect(row).not_to have_key('token')
    end

    it '404s a node without standing' do
      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
  describe 'DELETE #destroy' do
    it 'lets a member revoke rather than erase' do
      create(:company_membership, company: company, customer: user)
      invitation = create(:company_invitation, company: company)

      delete :destroy, params: { company_id: company.prefixed_id, id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(invitation.reload).to be_revoked
    end

    it 'refuses on an already spent invitation' do
      create(:company_membership, company: company, customer: user)
      invitation = create(:company_invitation, company: company, accepted_at: Time.current)

      delete :destroy, params: { company_id: company.prefixed_id, id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it '404s without standing' do
      invitation = create(:company_invitation, company: company)

      delete :destroy, params: { company_id: company.prefixed_id, id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
