require 'spec_helper'

RSpec.describe Spree::Api::V3::Seller::TeamController, type: :controller do
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

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it 'lists the seller team' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to include(seller_user.prefixed_id)
    end

    # The whole point of the branch: a seller reads their own team, never
    # another seller's and never the store's staff.
    it "does not list another seller's team" do
      other = create(:seller, :approved, store: store)
      outsider = create(:admin_user, :without_admin_role)
      other.add_user(outsider)

      get :index, as: :json

      expect(json_response['data'].pluck('id')).not_to include(outsider.prefixed_id)
    end
  end

  describe 'POST #create' do
    it 'invites someone onto the team' do
      expect do
        post :create, params: { email: 'colleague@example.com' }, as: :json
      end.to change { seller.invitations.count }.by(1)

      expect(response).to have_http_status(:created)
    end

    # The invitation lands on the seller's own role, so accepting it grants
    # access here and nowhere else.
    it "invites into the seller's own role" do
      post :create, params: { email: 'colleague@example.com' }, as: :json

      expect(seller.invitations.last.role.resource).to eq(seller)
    end

    # Hiring is not a lifecycle transition. `Spree::Sellers::Invite` means
    # "open this seller for its first owner" and would flip an approved seller
    # to `invited` — which is why team invites take the invitation rail
    # directly instead.
    it 'does not move the seller through its lifecycle' do
      expect do
        post :create, params: { email: 'colleague@example.com' }, as: :json
      end.not_to change { seller.reload.status }

      expect(seller).to be_approved
    end

    it 'reports a bad address' do
      post :create, params: { email: '' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'DELETE #destroy' do
    it 'revokes a member' do
      colleague = create(:admin_user, :without_admin_role)
      seller.add_user(colleague)

      expect do
        delete :destroy, params: { id: colleague.prefixed_id }, as: :json
      end.to change { seller.reload.users.count }.by(-1)

      expect(response).to have_http_status(:no_content)
    end

    # Emptying the team would leave a seller nobody can sign in to, and only
    # the marketplace operator could put someone back.
    it 'refuses to remove the last member' do
      delete :destroy, params: { id: seller_user.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.reload.users).to include(seller_user)
    end

    # `users` reaches through role_users, so one person holding two roles is
    # two rows — while removing them deletes both at once. Counted without
    # `distinct`, a one-person team would read as two and let them go.
    it 'refuses to remove the last member even when they hold two roles' do
      second_role = seller.roles.create!(name: "Packer #{SecureRandom.hex(3)}")
      seller.add_user(seller_user, second_role)
      expect(seller.reload.users.count).to eq(2)

      delete :destroy, params: { id: seller_user.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.reload.users).to include(seller_user)
    end

    # Counted and removed under a lock on the seller. Unlocked, two concurrent
    # deletes against a two-member team both observe two and both proceed,
    # leaving a seller nobody can sign in to — a state only an operator can
    # repair. Asserted here as the invariant: whatever the order of removals,
    # the team never reaches zero through this endpoint.
    it 'never lets the team reach zero' do
      second = create(:admin_user, :without_admin_role).tap { |user| seller.add_user(user) }

      delete :destroy, params: { id: second.prefixed_id }, as: :json
      expect(response).to have_http_status(:no_content)

      delete :destroy, params: { id: seller_user.prefixed_id }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(seller.reload.users.count).to eq(1)
    end
    it "404s on someone outside this seller's team" do
      other = create(:seller, :approved, store: store)
      outsider = create(:admin_user, :without_admin_role)
      other.add_user(outsider)
      seller.add_user(create(:admin_user, :without_admin_role))

      delete :destroy, params: { id: outsider.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
