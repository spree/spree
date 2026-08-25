require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CompanyMembersController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store) }
  let!(:other_membership) { create(:company_membership, company: company) }

  before { request.headers.merge!(headers) }

  describe 'DELETE #destroy' do
    # The accepted OSS trade-off: within a company, every member is trusted.
    it 'lets any member remove another member' do
      create(:company_membership, company: company, customer: user)

      delete :destroy, params: { id: other_membership.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CompanyMembership.where(id: other_membership.id)).to be_empty
    end

    it '404s without standing' do
      delete :destroy, params: { id: other_membership.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
