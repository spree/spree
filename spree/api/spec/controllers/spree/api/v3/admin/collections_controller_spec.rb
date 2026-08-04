require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::CollectionsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:collection) { create(:collection, store: store, name: 'Summer Sale') }
  let!(:other_store) { create(:store) }
  let!(:other_collection) { create(:collection, store: other_store) }

  before { request.headers.merge!(headers) }

  def created_collection
    Spree::Collection.find_by_prefix_id(json_response['id'])
  end

  describe 'GET #index' do
    it 'lists collections for the current store only' do
      get :index, params: {}, as: :json

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].map { |c| c['id'] }
      expect(ids).to include(collection.prefixed_id)
      expect(ids).not_to include(other_collection.prefixed_id)
    end

    it 'exposes the merchandising config + timestamps (admin surface)' do
      get :index, params: {}, as: :json

      data = json_response['data'].find { |c| c['id'] == collection.prefixed_id }
      expect(data).to include('automatic', 'rules_match_policy', 'rules', 'created_at', 'updated_at')
    end
  end

  describe 'GET #show' do
    let!(:automatic) { create(:automatic_collection, store: store, name: 'On Sale') }
    let!(:rule) { create(:tag_collection_rule, :contains, collection: automatic, value: 'summer') }

    it 'returns the collection with its rules' do
      get :show, params: { id: automatic.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['automatic']).to be(true)
      rules = json_response['rules']
      expect(rules.length).to eq(1)
      expect(rules.first).to include(
        'type' => 'Spree::CollectionRules::Tag', 'value' => 'summer', 'match_policy' => 'contains'
      )
      expect(rules.first['id']).to start_with('crule_')
    end

    it "returns not found for another store's collection" do
      get :show, params: { id: other_collection.prefixed_id }, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a manual collection owned by the store' do
      post :create, params: { name: 'New Arrivals' }, as: :json

      expect(response).to have_http_status(:created)
      created = created_collection
      expect(created.name).to eq('New Arrivals')
      expect(created.store).to eq(store)
      expect(created.automatic).to be(false)
    end

    it 'creates an automatic collection with typed rules from the flat rules payload' do
      post :create, params: {
        name: 'On Sale',
        automatic: true,
        rules_match_policy: 'any',
        rules: [
          { type: 'Spree::CollectionRules::Tag', value: 'summer', match_policy: 'contains' },
          { type: 'Spree::CollectionRules::Sale', value: 'true', match_policy: 'is_equal_to' }
        ]
      }, as: :json

      expect(response).to have_http_status(:created)
      created = created_collection
      expect(created.automatic).to be(true)
      expect(created.rules.map(&:type)).to match_array(
        %w[Spree::CollectionRules::Tag Spree::CollectionRules::Sale]
      )
    end

    it 'returns 422 for a blank name' do
      post :create, params: { name: '' }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    it 'updates collection attributes' do
      patch :update, params: { id: collection.prefixed_id, name: 'Winter Sale' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(collection.reload.name).to eq('Winter Sale')
    end

    # The full desired rule set is sent under `rules`: present ids update,
    # id-less entries create, omitted rules are destroyed (sync setter).
    context 'rules sync' do
      let!(:automatic) { create(:automatic_collection, store: store) }
      let!(:keep) { create(:tag_collection_rule, :contains, collection: automatic, value: 'keep') }
      let!(:drop) { create(:tag_collection_rule, :contains, collection: automatic, value: 'drop') }

      it 'updates present rules, creates new ones, and destroys omitted ones' do
        patch :update, params: {
          id: automatic.prefixed_id,
          rules: [
            { id: keep.prefixed_id, value: 'kept' },
            { type: 'Spree::CollectionRules::Sale', value: 'true', match_policy: 'is_equal_to' }
          ]
        }, as: :json

        expect(response).to have_http_status(:ok)
        automatic.reload
        expect(automatic.rules.count).to eq(2)
        expect(automatic.rules.find_by(id: keep.id).value).to eq('kept')
        expect(Spree::CollectionRule.find_by(id: drop.id)).to be_nil
        expect(automatic.rules.map(&:type)).to include('Spree::CollectionRules::Sale')
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the collection' do
      delete :destroy, params: { id: collection.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(Spree::Collection.find_by_prefix_id(collection.prefixed_id)).to be_nil
    end
  end

  # Flat acts_as_list: the collection's own order is reordered by sending
  # `position` on update (no dedicated reposition action) — acts_as_list shuffles
  # siblings on save.
  describe 'reordering via position on update' do
    let!(:c1) { create(:collection, store: store) }
    let!(:c2) { create(:collection, store: store) }
    let!(:c3) { create(:collection, store: store) }

    def ordered_trio
      trio = [c1.id, c2.id, c3.id]
      store.collections.reorder(:position).pluck(:id).select { |id| trio.include?(id) }
    end

    it 'moves a collection above its siblings when position is sent' do
      patch :update, params: { id: c3.prefixed_id, position: c1.reload.position }, as: :json

      expect(response).to have_http_status(:ok)
      expect(ordered_trio).to eq([c3.id, c1.id, c2.id])
    end
  end
end
