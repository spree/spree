require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::ExchangesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:shipped_order, store: store, line_items_count: 2) }
  let(:fulfillment_item) { order.fulfillment_items.first }
  let(:replacement) { create(:variant, product: fulfillment_item.variant.product) }

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    it 'opens an exchange' do
      post :create, params: {
        order_id: order.prefixed_id,
        memo: 'Wrong size',
        items: [{
          fulfillment_item_id: fulfillment_item.prefixed_id,
          new_variant_id: replacement.prefixed_id,
          quantity: 1
        }]
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['status']).to eq('requested')
      expect(json_response['number']).to start_with('EX')
    end

    it 'rejects exchanging an item for itself' do
      post :create, params: {
        order_id: order.prefixed_id,
        items: [{
          fulfillment_item_id: fulfillment_item.prefixed_id,
          new_variant_id: fulfillment_item.variant.prefixed_id,
          quantity: 1
        }]
      }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'GET #index' do
    it 'lists exchanges on the order' do
      create(:exchange, store: store, order: order)

      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
    end
  end

  describe 'PATCH #approve' do
    it 'approves a requested exchange' do
      exchange = create(:exchange, store: store, order: order)

      patch :approve, params: { order_id: order.prefixed_id, id: exchange.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['status']).to eq('approved')
    end
  end

  describe 'PATCH #receive' do
    it 'records a partial receipt' do
      exchange = create(:approved_exchange, store: store, order: order)
      line = exchange.exchange_line_items.first

      patch :receive, params: {
        order_id: order.prefixed_id,
        id: exchange.prefixed_id,
        items: [{ exchange_line_item_id: line.prefixed_id, quantity: 1, resellable: false }]
      }, as: :json

      expect(response).to have_http_status(:ok)
      expect(line.reload.resellable).to be(false)
    end
  end

  describe 'PATCH #cancel' do
    it 'refuses an exchange already received' do
      exchange = create(:received_exchange, store: store, order: order)

      patch :cancel, params: { order_id: order.prefixed_id, id: exchange.prefixed_id }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
