require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::ActivitiesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:completed_order_with_totals, store: store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    before do
      create(:order_activity, order: order, kind: 'order.placed', category: 'order', body: nil, created_at: 2.hours.ago)
      create(:order_activity, order: order, actor: admin_user, created_at: 1.hour.ago)
    end

    it 'lists the order’s entries newest first' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('kind')).to eq(%w[comment order.placed])
    end

    it 'sorts as the caller asks' do
      get :index, params: { order_id: order.prefixed_id, sort: 'created_at' }, as: :json

      expect(json_response['data'].pluck('kind')).to eq(%w[order.placed comment])
    end

    it 'filters by category' do
      get :index, params: { order_id: order.prefixed_id, q: { category_eq: 'comments' } }, as: :json

      expect(json_response['data'].pluck('kind')).to eq(%w[comment])
    end

    it 'expands the order change an entry records' do
      change = Spree::OrderChanges::Apply.call(order: order, actions: [{ kind: 'update_item', line_item: order.line_items.first, quantity: 2 }]).value
      create(:order_activity, order: order, kind: 'order_change.confirmed', category: 'changes', body: nil, order_change: change)

      get :index, params: { order_id: order.prefixed_id, expand: 'order_change.actions.variant' }, as: :json

      entry = json_response['data'].find { |activity| activity['kind'] == 'order_change.confirmed' }
      expect(entry['order_change']['actions'].sole['variant']['id']).to eq(order.line_items.first.variant.prefixed_id)
    end

    it 'never lists another order’s entries' do
      other = create(:completed_order_with_totals, store: store)
      create(:order_activity, order: other)

      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(json_response['data'].length).to eq(2)
    end

    it_behaves_like 'a list without N+1 queries' do
      before { create(:order_activity, order: order, actor: create(:admin_user)) }

      subject { get :index, params: { order_id: order.prefixed_id, expand: 'actor,order_change.actions.variant' }, as: :json }
    end
  end

  describe 'POST #create' do
    it 'adds a comment by the signed-in staff member' do
      post :create, params: { order_id: order.prefixed_id, body: 'Call before delivery' }, as: :json

      expect(response).to have_http_status(:created)
      comment = order.activities.sole
      expect([comment.kind, comment.body, comment.actor]).to eq(['comment', 'Call before delivery', admin_user])
    end

    context 'with an API key' do
      let(:headers) { api_key_headers }

      it 'records the key as the author' do
        post :create, params: { order_id: order.prefixed_id, body: 'Synced from the ERP' }, as: :json

        expect(order.activities.sole.actor).to eq(secret_api_key)
      end
    end

    it 'refuses an empty comment' do
      post :create, params: { order_id: order.prefixed_id, body: ' ' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'cannot comment on another store’s order' do
      other = create(:completed_order_with_totals, store: create(:store))

      post :create, params: { order_id: other.prefixed_id, body: 'Hello' }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes a comment its author wrote' do
      comment = create(:order_activity, order: order, actor: admin_user)

      delete :destroy, params: { order_id: order.prefixed_id, id: comment.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(order.activities.reload).to be_empty
    end

    it 'refuses someone else’s comment' do
      comment = create(:order_activity, order: order, actor: create(:admin_user))

      delete :destroy, params: { order_id: order.prefixed_id, id: comment.prefixed_id }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(comment.reload).to be_present
    end

    it 'refuses an entry that is not a comment' do
      entry = create(:order_activity, order: order, kind: 'order.placed', category: 'order', body: nil, actor: admin_user)

      delete :destroy, params: { order_id: order.prefixed_id, id: entry.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(entry.reload).to be_present
    end
  end
end
