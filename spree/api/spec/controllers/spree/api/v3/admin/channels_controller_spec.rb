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

    it 'does not publish a product owned by another store' do
      other_store = create(:store)
      cross_store = create(:product, store: other_store)

      post :add_products, params: {
        id: channel.prefixed_id, product_ids: [cross_store.prefixed_id]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['product_count']).to eq(0)
      expect(channel.reload.products).not_to include(cross_store)
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

    it 'persists the storefront gating preferences' do
      post :create, params: {
        name: 'B2B Portal', code: 'b2b',
        preferred_storefront_access: 'login_required',
        preferred_guest_checkout: false
      }, as: :json

      expect(response).to have_http_status(:created)

      created = Spree::Channel.find_by(code: 'b2b')
      expect(created.preferred_storefront_access).to eq('login_required')
      expect(created.preferred_guest_checkout).to be(false)
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

    it 'persists the storefront gating preferences' do
      patch :update, params: {
        id: channel.prefixed_id,
        preferred_storefront_access: 'prices_hidden',
        preferred_guest_checkout: false
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['preferred_storefront_access']).to eq('prices_hidden')
      expect(json_response['preferred_guest_checkout']).to be(false)

      channel.reload
      expect(channel.preferred_storefront_access).to eq('prices_hidden')
      expect(channel.preferred_guest_checkout).to be(false)
    end

    it 'clears the gating overrides back to store inheritance when set to null' do
      channel.update!(preferred_storefront_access: 'login_required', preferred_guest_checkout: false)

      patch :update, params: {
        id: channel.prefixed_id,
        preferred_storefront_access: nil,
        preferred_guest_checkout: nil
      }, as: :json

      expect(response).to have_http_status(:ok)

      channel.reload
      expect(channel.preferred_storefront_access).to be_nil
      expect(channel.preferred_guest_checkout).to be_nil
    end

    it 'rejects an invalid storefront access value with 422 and keeps the existing override' do
      channel.update!(preferred_storefront_access: 'prices_hidden')

      patch :update, params: {
        id: channel.prefixed_id,
        preferred_storefront_access: 'members_only'
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('validation_error')
      expect(channel.reload.preferred_storefront_access).to eq('prices_hidden')
    end
  end

  describe 'DELETE #destroy' do
    it 'destroys a non-default channel' do
      expect { delete :destroy, params: { id: channel.prefixed_id }, as: :json }
        .to change(Spree::Channel, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end

    it 'refuses to delete the default channel with 422' do
      default_channel = store.default_channel

      expect { delete :destroy, params: { id: default_channel.prefixed_id }, as: :json }
        .not_to change(Spree::Channel, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('validation_error')
    end
  end
  describe 'fulfillment-origin allowlist' do
    let!(:channel) { create(:channel, store: store) }
    let!(:warehouse) { create(:stock_location, store: store, name: 'Channel Warehouse') }

    it 'replaces the allowlist and serializes prefixed ids' do
      patch :update, params: { id: channel.prefixed_id, stock_location_ids: [warehouse.prefixed_id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['stock_location_ids']).to eq([warehouse.prefixed_id])

      patch :update, params: { id: channel.prefixed_id, stock_location_ids: [] }, as: :json
      expect(json_response['stock_location_ids']).to eq([])
    end

    it 'rejects a cross-store location with 404' do
      foreign = create(:stock_location, store: create(:store))

      patch :update, params: { id: channel.prefixed_id, stock_location_ids: [foreign.prefixed_id] }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'default catalog' do
    let!(:catalog) { create(:catalog, store: store) }

    it 'sets the default catalog and serializes its prefixed id' do
      patch :update, params: { id: channel.prefixed_id, default_catalog_id: catalog.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['default_catalog_id']).to eq(catalog.prefixed_id)
      expect(channel.reload.default_catalog).to eq(catalog)
    end

    it 'clears the default catalog when set to null, restoring every published product' do
      channel.update!(default_catalog: catalog)

      patch :update, params: { id: channel.prefixed_id, default_catalog_id: nil }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['default_catalog_id']).to be_nil
      expect(channel.reload.default_catalog).to be_nil
    end

    it 'rejects a cross-store catalog with 404' do
      foreign = create(:catalog, store: create(:store))

      patch :update, params: { id: channel.prefixed_id, default_catalog_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(channel.reload.default_catalog).to be_nil
    end
  end

  describe 'market allowlist' do
    let!(:channel) { create(:channel, store: store) }
    let!(:eu) { create(:market, store: store, name: 'EU', currency: 'EUR') }

    it 'replaces the allowlist and serializes prefixed ids' do
      patch :update, params: { id: channel.prefixed_id, market_ids: [eu.prefixed_id] }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['market_ids']).to eq([eu.prefixed_id])

      patch :update, params: { id: channel.prefixed_id, market_ids: [] }, as: :json
      expect(json_response['market_ids']).to eq([])
    end

    it 'rejects a cross-store market with 404' do
      foreign = create(:market, store: create(:store))

      patch :update, params: { id: channel.prefixed_id, market_ids: [foreign.prefixed_id] }, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'sets and clears the default market' do
      patch :update, params: { id: channel.prefixed_id, default_market_id: eu.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['default_market_id']).to eq(eu.prefixed_id)

      patch :update, params: { id: channel.prefixed_id, default_market_id: nil }, as: :json

      expect(json_response['default_market_id']).to be_nil
      expect(channel.reload.default_market).to be_nil
    end

    it 'rejects a cross-store default market with 404' do
      foreign = create(:market, store: create(:store))

      patch :update, params: { id: channel.prefixed_id, default_market_id: foreign.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
      expect(channel.reload.default_market).to be_nil
    end
  end
end
