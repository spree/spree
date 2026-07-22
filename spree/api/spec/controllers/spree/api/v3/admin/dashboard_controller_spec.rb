require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::DashboardController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  before { request.headers.merge!(headers) }

  describe 'GET #operations' do
    subject { get :operations, as: :json }

    it 'returns all counters' do
      subject
      expect(response).to have_http_status(:ok)
      expect(json_response).to include(
        'low_stock_threshold', 'orders_to_fulfill', 'payments_to_collect',
        'open_returns', 'low_stock_items', 'out_of_stock_items'
      )
    end

    context 'with actionable orders' do
      let!(:ready_order) { create(:order_ready_to_ship, store: store) }
      let!(:balance_due_order) do
        create(:completed_order_with_totals, store: store, payment_state: 'balance_due', shipment_state: 'shipped')
      end

      it 'counts orders to fulfill and payments to collect' do
        subject
        expect(json_response['orders_to_fulfill']).to eq(1)
        expect(json_response['payments_to_collect']).to eq(1)
      end

      it 'scopes order counts to the requested channel' do
        channel = create(:channel, store: store)
        create(:order_ready_to_ship, store: store, channel: channel)

        get :operations, params: { channel_id: channel.prefixed_id }, as: :json
        expect(json_response['channel_id']).to eq(channel.prefixed_id)
        expect(json_response['orders_to_fulfill']).to eq(1)
        expect(json_response['payments_to_collect']).to eq(0)
      end
    end

    context 'with an open return' do
      let!(:return_authorization) { create(:return_authorization) }

      it 'counts authorized return authorizations' do
        subject
        expect(json_response['open_returns']).to eq(1)
      end
    end

    context 'with stock levels' do
      let!(:low_stock_product) { create(:product, store: store) }
      let!(:out_of_stock_product) { create(:product, store: store) }

      before do
        low_stock_product.master.stock_items.first.set_count_on_hand(3)
      end

      it 'counts low stock and out of stock variants' do
        subject
        expect(json_response['low_stock_items']).to eq(1)
        expect(json_response['out_of_stock_items']).to eq(1)
      end

      it 'respects the low_stock_threshold param' do
        get :operations, params: { low_stock_threshold: 2 }, as: :json
        expect(json_response['low_stock_threshold']).to eq(2)
        expect(json_response['low_stock_items']).to eq(0)
      end

      it 'ignores variants that do not track inventory' do
        low_stock_product.master.update!(track_inventory: false)
        out_of_stock_product.master.update!(track_inventory: false)
        subject
        expect(json_response['low_stock_items']).to eq(0)
        expect(json_response['out_of_stock_items']).to eq(0)
      end
    end

    context 'without authentication' do
      let(:headers) { {} }

      it 'returns unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
