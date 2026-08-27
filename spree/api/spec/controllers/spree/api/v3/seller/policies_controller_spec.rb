require 'spec_helper'

# A seller's policies are their own legal documents. The isolation that
# matters here runs three ways: another seller's policies, the operator's
# store policies, and — on writes — a payload trying to claim either.
RSpec.describe Spree::Api::V3::Seller::PoliciesController, type: :controller do
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

  let!(:mine) do
    create(:policy, owner: seller, name: 'My Returns Policy', body: '<p>Thirty days.</p>')
  end
  let(:other_seller) { create(:seller, :approved, store: store) }
  let!(:theirs) { create(:policy, owner: other_seller, name: 'Their Returns Policy') }
  let!(:store_policy) { create(:policy, owner: store, name: 'Marketplace Terms') }

  before do
    request.headers['Authorization'] = "Bearer #{token}"
    request.headers['X-Spree-Seller-Id'] = seller.prefixed_id
  end

  describe 'GET #index' do
    it "lists only this seller's policies" do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      names = json_response['data'].pluck('name')
      expect(names).to include('My Returns Policy')
      expect(names).not_to include('Their Returns Policy', 'Marketplace Terms')
    end
  end

  describe 'GET #show' do
    it 'returns the policy' do
      get :show, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('My Returns Policy')
      expect(json_response['body_html']).to include('Thirty days.')
      expect(json_response['updated_at']).to be_present
    end

    it "returns 404 for another seller's policy" do
      get :show, params: { id: theirs.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 for the marketplace's own policy" do
      get :show, params: { id: store_policy.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a policy owned by this seller' do
      post :create, params: { name: 'Shipping Policy', body: '<p>We ship in two days.</p>' }, as: :json

      expect(response).to have_http_status(:created)
      policy = seller.policies.find_by_prefix_id!(json_response['id'])
      expect(policy.owner).to eq(seller)
      expect(policy.body_html).to include('two days')
    end

    it 'sanitizes the body it stores' do
      post :create, params: { name: 'Terms', body: '<p>Fine</p><script>alert(1)</script>' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['body_html']).not_to include('<script>')
    end
  end

  describe 'PATCH #update' do
    it 'updates the policy' do
      patch :update, params: { id: mine.prefixed_id, body: '<p>Sixty days.</p>' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(mine.reload.body_html).to include('Sixty days.')
    end

    it "does not update another seller's policy" do
      patch :update, params: { id: theirs.prefixed_id, name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.name).to eq('Their Returns Policy')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the policy' do
      delete :destroy, params: { id: mine.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Policy.where(id: mine.id)).to be_empty
    end

    it "does not delete the marketplace's own policy" do
      delete :destroy, params: { id: store_policy.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(store_policy.reload).to be_present
    end
  end
end
