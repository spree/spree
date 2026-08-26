require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Companies::MembersController, type: :controller do
  render_views

  include_context 'API v3 Store authenticated'

  let(:company) { create(:company, store: store) }

  before do
    create(:company_membership, company: company, customer: user)
    request.headers.merge!(headers)
  end

  describe 'GET #index' do
    it 'lists the members with who they are' do
      get :index, params: { company_id: company.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].sole['email']).to eq(user.email)
    end

    it '404s a node without standing' do
      other = create(:company, store: store)

      get :index, params: { company_id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'adds an existing customer as a member immediately' do
      buyer = create(:customer, email: 'colleague@example.com')

      post :create, params: { company_id: company.prefixed_id, customer_email: 'colleague@example.com' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to start_with('cmem_')
      expect(company.memberships.reload.map(&:customer)).to include(buyer)
    end

    it 'invites an unknown email, recording the inviter' do
      post :create, params: { company_id: company.prefixed_id, customer_email: 'new@example.com' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['id']).to start_with('cinv_')
      expect(json_response).not_to have_key('token')
      expect(company.invitations.sole.inviter).to eq(user)
    end

    it 'lets a member of an ancestor act on a division' do
      division = create(:company, store: store, kind: 'division', parent: company)
      create(:customer, email: 'colleague@example.com')

      post :create, params: { company_id: division.prefixed_id, customer_email: 'colleague@example.com' }, as: :json

      expect(response).to have_http_status(:created)
    end
  end
  describe 'DELETE #destroy' do
    # OSS ships no company roles: any member may manage the directory.
    it 'lets any member remove another member' do
      other = create(:company_membership, company: company)

      delete :destroy, params: { company_id: company.prefixed_id, id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::CompanyMembership.find_by(id: other.id)).to be_nil
    end

    it '404s a member of a node the caller has no standing over' do
      other_company = create(:company, store: store)
      other = create(:company_membership, company: other_company)

      delete :destroy, params: { company_id: other_company.prefixed_id, id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
