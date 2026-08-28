require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::PoliciesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:restocking_policy) do
    create(:policy, owner: store, name: 'Restocking Policy', slug: 'restocking-policy', body: '<p>Send it back.</p>')
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the store’s policies' do
      get :index, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].map { |policy| policy['id'] }).to include(restocking_policy.prefixed_id)
    end

    it 'does not return policies belonging to another store' do
      other_policy = create(:policy, owner: create(:store), name: 'Elsewhere')

      get :index, as: :json

      expect(json_response['data'].map { |policy| policy['id'] }).not_to include(other_policy.prefixed_id)
    end

    # Seller policies are the seller's to manage, on their own branch.
    it 'does not return a seller’s policies' do
      seller_policy = create(:policy, owner: create(:seller, store: store), name: 'Seller Returns')

      get :index, as: :json

      expect(json_response['data'].map { |policy| policy['id'] }).not_to include(seller_policy.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns the policy by prefixed id' do
      get :show, params: { id: restocking_policy.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Restocking Policy')
      expect(json_response['body_html']).to include('Send it back.')
      expect(json_response['created_at']).to be_present
      expect(json_response['updated_at']).to be_present
    end

    it 'returns the policy by slug' do
      get :show, params: { id: 'restocking-policy' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(restocking_policy.prefixed_id)
    end

    it 'returns 404 for a policy owned by another store' do
      other_policy = create(:policy, owner: create(:store))

      get :show, params: { id: other_policy.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a policy owned by the current store' do
      post :create, params: { name: 'Wholesale Policy', body: '<p>We ship worldwide.</p>' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Wholesale Policy')
      expect(json_response['slug']).to eq('wholesale-policy')

      policy = store.policies.find_by_prefix_id!(json_response['id'])
      expect(policy.body_html).to include('We ship worldwide.')
    end

    it 'sanitizes the body it stores' do
      post :create, params: { name: 'Terms', body: '<p>Fine</p><script>alert(1)</script>' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['body_html']).to include('Fine')
      expect(json_response['body_html']).not_to include('<script>')
    end

    it 'rejects a policy with no name' do
      post :create, params: { body: '<p>Nameless.</p>' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates the policy' do
      patch :update, params: { id: restocking_policy.prefixed_id, body: '<p>Thirty days.</p>' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(restocking_policy.reload.body_html).to include('Thirty days.')
    end

    it 'does not update a policy owned by another store' do
      other_policy = create(:policy, owner: create(:store), name: 'Elsewhere')

      patch :update, params: { id: other_policy.prefixed_id, name: 'Hijacked' }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(other_policy.reload.name).to eq('Elsewhere')
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the policy' do
      delete :destroy, params: { id: restocking_policy.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Policy.where(id: restocking_policy.id)).to be_empty
    end
  end
end
