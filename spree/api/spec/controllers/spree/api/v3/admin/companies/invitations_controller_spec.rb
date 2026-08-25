require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Companies::InvitationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists the node invitations with their derived status' do
      pending_invitation = create(:company_invitation, company: company)
      expired = create(:company_invitation, company: company)
      expired.update!(expires_at: 1.day.ago)

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      statuses = json_response['data'].to_h { |row| [row['id'], row['status']] }
      expect(statuses[pending_invitation.prefixed_id]).to eq('pending')
      expect(statuses[expired.prefixed_id]).to eq('expired')
    end

    it '404s under another store company' do
      get :index, params: { company_id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
