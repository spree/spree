require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::PoliciesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
  end

  let!(:return_policy) { create(:policy, owner: store, name: 'Return Policy', slug: 'return-policy', body: 'You can return within 30 days.') }
  let!(:privacy_policy) { create(:policy, owner: store, name: 'Privacy Policy', slug: 'privacy-policy', body: 'We respect your privacy.') }

  describe 'GET #index' do
    it 'returns policies for the store' do
      get :index

      expect(response).to have_http_status(:ok)
      slugs = json_response['data'].map { |p| p['slug'] }
      expect(slugs).to include('return-policy', 'privacy-policy')
    end

    it 'returns policy attributes' do
      get :index

      policy = json_response['data'].find { |p| p['slug'] == 'return-policy' }
      expect(policy['id']).to start_with('pol_')
      expect(policy['name']).to eq('Return Policy')
      expect(policy['slug']).to eq('return-policy')
    end

    it 'orders by name' do
      get :index

      names = json_response['data'].map { |p| p['name'] }
      expect(names).to eq(names.sort)
    end

    it 'does not return policies from other stores' do
      other_store = create(:store)
      create(:policy, owner: other_store, name: 'Other Policy', slug: 'other-policy')

      get :index

      slugs = json_response['data'].map { |p| p['slug'] }
      expect(slugs).not_to include('other-policy')
    end
  end

  describe 'GET #show' do
    it 'returns a policy by slug' do
      get :show, params: { id: 'return-policy' }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to start_with('pol_')
      expect(json_response['name']).to eq('Return Policy')
      expect(json_response['slug']).to eq('return-policy')
      expect(json_response['body']).to include('return within 30 days')
    end

    it 'returns a policy by prefixed ID' do
      get :show, params: { id: return_policy.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['name']).to eq('Return Policy')
    end

    it 'returns 404 for non-existent policy' do
      get :show, params: { id: 'non-existent-policy' }

      expect(response).to have_http_status(:not_found)
    end
  end
end
