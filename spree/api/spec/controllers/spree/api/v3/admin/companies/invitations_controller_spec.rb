require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Companies::InvitationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:company) { create(:company, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    # Narrowed in the endpoint, before pagination — a page of spent rows would
    # otherwise push live invitations off the first page and make the count
    # describe the wrong set.
    it 'lists the pending invitations and leaves spent ones out' do
      pending_invitation = create(:company_invitation, company: company)
      expired = create(:company_invitation, company: company)
      expired.update!(expires_at: 1.day.ago)
      revoked = create(:company_invitation, company: company)
      revoked.revoke!

      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      rows = json_response['data'].to_h { |row| [row['id'], row['status']] }
      expect(rows).to eq(pending_invitation.prefixed_id => 'pending')
    end

    it '404s under another store company' do
      get :index, params: { company_id: create(:company, store: create(:store)).prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
