require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::ChannelsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:channel) { create(:channel, store: store, name: 'Wholesale', code: 'wholesale') }
  let!(:product) { create(:product) }

  before { request.headers.merge!(headers) }

  describe 'POST #add_products' do
    let!(:other_product) { create(:product) }

    before { Spree::ProductPublication.where(channel: channel).delete_all }

    it 'publishes the listed products on the channel' do
      post :add_products, params: {
        id: channel.prefixed_id,
        product_ids: [product.prefixed_id, other_product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2)
      expect(channel.reload.products).to include(product, other_product)
    end

    it 'is idempotent — re-publishing existing products does not duplicate' do
      channel.add_products([product.id])

      expect do
        post :add_products, params: {
          id: channel.prefixed_id, product_ids: [product.prefixed_id]
        }, as: :json
      end.not_to change { Spree::ProductPublication.where(channel: channel).count }

      expect(response).to have_http_status(:ok)
    end

    it 'publishes a product that has no publications yet (first-time onboarding)' do
      fresh = create(:product)
      Spree::ProductPublication.where(product: fresh).delete_all

      post :add_products, params: {
        id: channel.prefixed_id, product_ids: [fresh.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
      expect(channel.reload.products).to include(fresh)
    end

    it 'co-publishes a product from another store onto this channel' do
      other_store = create(:store)
      cross_store = create(:product, store: other_store)

      post :add_products, params: {
        id: channel.prefixed_id, product_ids: [cross_store.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(channel.reload.products).to include(cross_store)
    end

    it 'accepts an ISO8601 published_at window' do
      future = 2.days.from_now.change(usec: 0)

      post :add_products, params: {
        id: channel.prefixed_id,
        product_ids: [product.prefixed_id],
        published_at: future.iso8601
      }, as: :json

      expect(response).to have_http_status(:ok)
      publication = Spree::ProductPublication.find_by(channel: channel, product: product)
      expect(publication.published_at).to be_within(1.second).of(future)
    end

    it 'is a no-op when product_ids is empty' do
      expect do
        post :add_products, params: {
          id: channel.prefixed_id, product_ids: []
        }, as: :json
      end.not_to change(Spree::ProductPublication, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0)
    end

    it '404s when the channel belongs to a different store' do
      foreign_channel = create(:channel, store: create(:store), code: 'foreign')

      post :add_products, params: {
        id: foreign_channel.prefixed_id, product_ids: [product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #remove_products' do
    let!(:other_product) { create(:product) }

    before do
      channel.add_products([product.id, other_product.id])
    end

    it 'unpublishes the listed products from the channel' do
      post :remove_products, params: {
        id: channel.prefixed_id,
        product_ids: [product.prefixed_id, other_product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 2)
      expect(channel.reload.products).not_to include(product, other_product)
    end

    it 'leaves untouched products published' do
      post :remove_products, params: {
        id: channel.prefixed_id, product_ids: [product.prefixed_id]
      }, as: :json

      expect(channel.reload.products).not_to include(product)
      expect(channel.reload.products).to include(other_product)
    end

    it 'is a no-op for products not currently on the channel' do
      stray = create(:product)

      expect do
        post :remove_products, params: {
          id: channel.prefixed_id, product_ids: [stray.prefixed_id]
        }, as: :json
      end.not_to change(Spree::ProductPublication, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('product_count' => 0)
    end

    it 'is a no-op for products that have no publication on this channel' do
      other_store = create(:store)
      foreign = create(:product, store: other_store)

      expect do
        post :remove_products, params: {
          id: channel.prefixed_id,
          product_ids: [product.prefixed_id, foreign.prefixed_id]
        }, as: :json
      end.to change { Spree::ProductPublication.where(channel: channel).count }.by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(1)
    end

    it '404s when the channel belongs to a different store' do
      foreign_channel = create(:channel, store: create(:store), code: 'foreign')

      post :remove_products, params: {
        id: foreign_channel.prefixed_id, product_ids: [product.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST #create' do
    it 'creates a new channel and demotes the previous default when default=true' do
      previous_default = store.default_channel
      expect(previous_default).to be_present
      expect(previous_default.default).to be true

      post :create, params: {
        name: 'Point of Sale', code: 'pos', active: true, default: true
      }, as: :json

      expect(response).to have_http_status(:created)
      new_channel = Spree::Channel.find_by(code: 'pos')
      expect(new_channel.default).to be true
      expect(previous_default.reload.default).to be false
    end

    it 'leaves the existing default in place when default=false' do
      previous_default = store.default_channel

      post :create, params: {
        name: 'Point of Sale', code: 'pos', active: true, default: false
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(Spree::Channel.find_by(code: 'pos').default).to be false
      expect(previous_default.reload.default).to be true
    end
  end

  describe 'PATCH #update' do
    it 'promotes a non-default channel and demotes the previous default' do
      previous_default = store.default_channel
      expect(channel.default).to be false

      patch :update, params: { id: channel.prefixed_id, default: true }, as: :json

      expect(response).to have_http_status(:ok)
      expect(channel.reload.default).to be true
      expect(previous_default.reload.default).to be false
    end

    it 'persists preferred_order_routing_strategy' do
      patch :update, params: {
        id: channel.prefixed_id,
        preferred_order_routing_strategy: 'Spree::OrderRouting::Strategy::Rules'
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(channel.reload.preferred_order_routing_strategy).to eq('Spree::OrderRouting::Strategy::Rules')
    end

    it 'clears the channel-level override when set to null' do
      channel.update!(preferred_order_routing_strategy: 'Spree::OrderRouting::Strategy::Rules')

      patch :update, params: {
        id: channel.prefixed_id,
        preferred_order_routing_strategy: nil
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(channel.reload.preferred_order_routing_strategy).to be_blank
    end
  end
end
