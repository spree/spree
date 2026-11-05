require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::CollectionsController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:collection) { create(:collection, store: store, name: 'Summer Sale') }
  let!(:other_store) { create(:store) }
  let!(:other_collection) { create(:collection, store: other_store) }

  before { request.headers['X-Spree-Api-Key'] = api_key.token }

  describe 'GET #index' do
    it 'returns collections for the current store only' do
      get :index

      expect(response).to have_http_status(:ok)
      ids = json_response['data'].pluck('id')
      expect(ids).to include(collection.prefixed_id)
      expect(ids).not_to include(other_collection.prefixed_id)
    end

    it 'exposes customer-facing attributes but not the merchandising config' do
      get :index

      data = json_response['data'].find { |c| c['id'] == collection.prefixed_id }
      expect(data).to include('name', 'permalink', 'sort_order', 'products_count', 'description', 'image_url')
      expect(data).not_to include('automatic', 'rules_match_policy', 'rules')
    end

    context 'without API key' do
      before { request.headers['X-Spree-Api-Key'] = nil }

      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET #show' do
    it 'finds by permalink' do
      get :show, params: { id: collection.permalink }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(collection.prefixed_id)
      expect(json_response['name']).to eq('Summer Sale')
    end

    it 'finds by prefixed id' do
      get :show, params: { id: collection.prefixed_id }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(collection.prefixed_id)
    end

    it 'omits the merchandising config' do
      get :show, params: { id: collection.prefixed_id }

      expect(json_response).not_to include('automatic', 'rules_match_policy', 'rules')
    end

    it "returns not found for another store's collection" do
      get :show, params: { id: other_collection.permalink }

      expect(response).to have_http_status(:not_found)
    end

    it 'finds a permalink containing an underscore' do
      # Generated permalinks turn underscores into hyphens; imported ones keep them.
      underscored = create(:collection, store: store, name: 'Beach')
      underscored.update_columns(permalink: 'summer_sale')

      get :show, params: { id: 'summer_sale' }

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(underscored.prefixed_id)
    end

    context 'after a rename' do
      before { collection.update!(permalink: 'summer-deals') }

      it 'resolves the old permalink and returns the current one' do
        get :show, params: { id: 'summer-sale' }

        expect(response).to have_http_status(:ok)
        expect(json_response['id']).to eq(collection.prefixed_id)
        expect(json_response['permalink']).to eq('summer-deals')
      end

      it 'returns not found for an old permalink of an unpublished collection' do
        collection.publications.destroy_all

        get :show, params: { id: 'summer-sale' }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'image alt text' do
      it 'is null without an image' do
        get :show, params: { id: collection.prefixed_id }

        expect(json_response).to include('image_alt' => nil, 'square_image_alt' => nil)
      end

      it 'comes from the media library placement of the image' do
        with_image = create(:collection, :with_image, store: store)
        with_image.media.first.update!(alt: 'Summer hats on a beach')

        get :show, params: { id: with_image.prefixed_id }

        expect(json_response['image_alt']).to eq('Summer hats on a beach')
        expect(json_response['square_image_alt']).to be_nil
      end
    end
  end

  describe 'publishing' do
    let(:other_channel) { create(:channel, store: store) }

    it 'hides an unpublished collection from the list and show' do
      hidden = create(:collection, :unpublished, store: store)

      get :index
      expect(json_response['data'].pluck('id')).not_to include(hidden.prefixed_id)

      get :show, params: { id: hidden.permalink }
      expect(response).to have_http_status(:not_found)
    end

    it 'hides a collection published only on another channel' do
      elsewhere = create(:collection, :unpublished, store: store)
      create(:collection_publication, collection: elsewhere, channel: other_channel)

      get :show, params: { id: elsewhere.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'hides a collection scheduled for later' do
      scheduled = create(:collection, :unpublished, store: store)
      create(:collection_publication, collection: scheduled, channel: store.default_channel, published_at: 1.day.from_now)

      get :show, params: { id: scheduled.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end

    it 'hides a collection whose window has closed' do
      ended = create(:collection, :unpublished, store: store)
      create(:collection_publication, collection: ended, channel: store.default_channel,
                                      published_at: 2.days.ago, unpublished_at: 1.day.ago)

      get :show, params: { id: ended.prefixed_id }

      expect(response).to have_http_status(:not_found)
    end
  end
end
