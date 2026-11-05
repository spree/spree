require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Collections::PublicationsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:collection) { create(:collection, :unpublished, store: store) }
  let!(:pos) { create(:channel, store: store, name: 'POS') }
  let(:other_store) { create(:store) }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:publication) { create(:collection_publication, collection: collection, channel: store.default_channel) }

    it 'lists the collection publications' do
      get :index, params: { collection_id: collection.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].pluck('id')).to eq([publication.prefixed_id])
      expect(json_response['data'].first).to include('channel_id' => store.default_channel.prefixed_id,
                                                     'collection_id' => collection.prefixed_id)
    end

    it_behaves_like 'a list without N+1 queries' do
      subject { get :index, params: { collection_id: collection.prefixed_id }, as: :json }

      let!(:more_publications) do
        create_list(:channel, 2, store: store).map do |channel|
          create(:collection_publication, collection: collection, channel: channel)
        end
      end
    end

    it "returns not found for another store's collection" do
      foreign = create(:collection, store: other_store)

      get :index, params: { collection_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'publishes the collection on a channel with a window' do
      published_at = 1.day.from_now.change(usec: 0)

      post :create, params: { collection_id: collection.prefixed_id, channel_id: pos.prefixed_id,
                              published_at: published_at.iso8601 }, as: :json

      expect(response).to have_http_status(:created)
      publication = collection.publications.reload.first
      expect(publication.channel).to eq(pos)
      expect(publication.published_at).to eq(published_at)
    end

    it "returns not found for another store's channel" do
      foreign_channel = create(:channel, store: other_store)

      post :create, params: { collection_id: collection.prefixed_id, channel_id: foreign_channel.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(collection.publications.reload).to be_empty
    end

    it 'refuses a window that ends before it starts' do
      post :create, params: { collection_id: collection.prefixed_id, channel_id: pos.prefixed_id,
                              published_at: 2.days.from_now.iso8601, unpublished_at: 1.day.from_now.iso8601 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a second publication on the same channel' do
      create(:collection_publication, collection: collection, channel: pos)

      post :create, params: { collection_id: collection.prefixed_id, channel_id: pos.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let!(:publication) { create(:collection_publication, collection: collection, channel: pos) }

    it 'changes the window and keeps the channel' do
      unpublished_at = 3.days.from_now.change(usec: 0)

      patch :update, params: { collection_id: collection.prefixed_id, id: publication.prefixed_id,
                               unpublished_at: unpublished_at.iso8601, channel_id: store.default_channel.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(publication.reload.unpublished_at).to eq(unpublished_at)
      expect(publication.channel).to eq(pos)
    end
  end

  describe 'DELETE #destroy' do
    let!(:publication) { create(:collection_publication, collection: collection, channel: pos) }

    it 'unpublishes the collection from the channel' do
      delete :destroy, params: { collection_id: collection.prefixed_id, id: publication.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(collection.publications.reload).to be_empty
    end
  end
end
