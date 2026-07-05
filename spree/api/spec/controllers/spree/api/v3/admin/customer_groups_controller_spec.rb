require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CustomerGroupsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:customer_group) { create(:customer_group, store: store, name: 'VIPs', description: 'Top spenders') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    subject { get :index, as: :json }

    it 'returns customer groups in the current store' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].map { |g| g['id'] }).to include(customer_group.prefixed_id)
      expect(json_response['data'].first['customers_count']).to eq(0)
    end

    it 'excludes groups from other stores' do
      other_store = create(:store)
      other_group = create(:customer_group, store: other_store, name: 'Other')

      subject
      ids = json_response['data'].map { |g| g['id'] }
      expect(ids).to include(customer_group.prefixed_id)
      expect(ids).not_to include(other_group.prefixed_id)
    end

    it 'does not embed customers in the list payload' do
      create(:user).then { |u| customer_group.customers << u }

      subject
      entry = json_response['data'].find { |g| g['id'] == customer_group.prefixed_id }
      expect(entry).not_to have_key('customers')
      expect(entry['customers_count']).to eq(1)
    end
  end

  describe 'GET #show' do
    subject { get :show, params: { id: customer_group.prefixed_id }, as: :json }

    it 'returns the group without customers by default' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(customer_group.prefixed_id)
      expect(json_response['name']).to eq('VIPs')
      expect(json_response['description']).to eq('Top spenders')
      expect(json_response).not_to have_key('customers')
    end

    it 'embeds customers when expand=customers is passed' do
      user = create(:user, email: 'vip@example.com')
      customer_group.customers << user

      get :show, params: { id: customer_group.prefixed_id, expand: 'customers' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['customers']).to be_an(Array)
      expect(json_response['customers'].map { |c| c['email'] }).to include('vip@example.com')
    end

    it 'returns 404 for a group from another store' do
      other_group = create(:customer_group, store: create(:store))

      get :show, params: { id: other_group.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    let(:create_params) { { name: 'Wholesale', description: 'B2B accounts' } }

    it 'creates a group scoped to the current store' do
      expect { post :create, params: create_params, as: :json }.to change(Spree::CustomerGroup, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['name']).to eq('Wholesale')
      expect(json_response['description']).to eq('B2B accounts')
      expect(json_response['customers_count']).to eq(0)
      expect(Spree::CustomerGroup.last.store).to eq(store)
    end

    it 'attaches customers when customer_ids is given (decodes prefixed IDs)' do
      alice = create(:user, email: 'alice@example.com')
      bob = create(:user, email: 'bob@example.com')

      post :create, params: create_params.merge(customer_ids: [alice.prefixed_id, bob.prefixed_id]), as: :json

      expect(response).to have_http_status(:created)
      group = Spree::CustomerGroup.find(Spree::PrefixedId.decode_prefixed_id(json_response['id']))
      expect(group.customers).to match_array([alice, bob])
    end

    it 'returns 422 when name is missing' do
      post :create, params: { description: 'no name' }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when name is duplicated within the same store' do
      post :create, params: { name: 'VIPs' }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates name and description' do
      patch :update, params: { id: customer_group.prefixed_id, name: 'Updated', description: 'New desc' }, as: :json

      expect(response).to have_http_status(:ok)
      customer_group.reload
      expect(customer_group.name).to eq('Updated')
      expect(customer_group.description).to eq('New desc')
    end

    it 'reconciles customer_ids on update (adds + removes)' do
      alice = create(:user)
      bob = create(:user)
      carol = create(:user)
      customer_group.customers << [alice, bob]

      patch :update, params: { id: customer_group.prefixed_id, customer_ids: [bob.prefixed_id, carol.prefixed_id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(customer_group.reload.customers).to match_array([bob, carol])
    end

    it 'clears membership when an empty array is sent' do
      customer_group.customers << create(:user)

      patch :update, params: { id: customer_group.prefixed_id, customer_ids: [] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(customer_group.reload.customers).to be_empty
    end

    it 'returns 404 for a group from another store' do
      other_group = create(:customer_group, store: create(:store))

      patch :update, params: { id: other_group.prefixed_id, name: 'Hacked' }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'soft-deletes the customer group' do
      target = create(:customer_group, store: store)

      expect { delete :destroy, params: { id: target.prefixed_id }, as: :json }.
        to change { Spree::CustomerGroup.where(id: target.id).count }.by(-1)

      expect(response).to have_http_status(:no_content)
      expect(Spree::CustomerGroup.with_deleted.exists?(id: target.id)).to be true
    end

    it 'returns 404 for a group from another store' do
      other_group = create(:customer_group, store: create(:store))

      delete :destroy, params: { id: other_group.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end
end
