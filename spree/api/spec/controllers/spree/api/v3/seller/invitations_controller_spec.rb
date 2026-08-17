require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::InvitationsController, type: :controller do
  render_views

  include_context 'API v3 Seller'

  let(:seller_user) do
    create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }
  end
  let(:token) do
    Spree::Api::V3::TestingSupport.generate_jwt(
      seller_user, audience: Spree::Api::V3::JwtAuthentication::JWT_AUDIENCE_SELLER
    )
  end

  let!(:invitation) do
    create(:invitation, resource: seller, inviter: seller_user,
                        email: 'pending@example.com', role: seller.default_user_role)
  end

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it 'lists offers nobody has accepted yet' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('email')).to include('pending@example.com')
    end

    it 'carries a link the panel can hand to a colleague' do
      get :index, as: :json

      expect(json_response['data'].first['acceptance_url']).to include(invitation.prefixed_id)
    end

    # An accepted invitation is a team member, and the panel lists those
    # separately — showing it here would double-count the person.
    it 'omits invitations that were accepted' do
      invitation.invitee = create(:admin_user, email: invitation.email)
      invitation.accept!

      get :index, as: :json

      expect(json_response['data']).to be_empty
    end

    it "does not list another seller's invitations" do
      other = create(:seller, :approved, store: store)
      create(:invitation, resource: other, inviter: seller_user, email: 'elsewhere@example.com')

      get :index, as: :json

      expect(json_response['data'].pluck('email')).not_to include('elsewhere@example.com')
    end
  end

  describe 'PATCH #resend' do
    it 'sends the offer again' do
      patch :resend, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it 'refuses once the offer has lapsed' do
      invitation.update_column(:expires_at, 1.day.ago)

      patch :resend, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "404s on another seller's invitation" do
      other = create(:seller, :approved, store: store)
      theirs = create(:invitation, resource: other, inviter: seller_user)

      patch :resend, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'withdraws the offer' do
      delete :destroy, params: { id: invitation.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(seller.reload.invitations.pending).to be_empty
    end

    it "404s on another seller's invitation" do
      other = create(:seller, :approved, store: store)
      theirs = create(:invitation, resource: other, inviter: seller_user)

      delete :destroy, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload).to be_present
    end
  end
end
