require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::FeesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:line_item) { order.line_items.first }
  let!(:fee) { create(:fee, line_item: line_item, order: order, amount: 5.99, kind: 'gift_wrap') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the order fees' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first).to include(
        'id' => fee.prefixed_id,
        'amount' => '5.99',
        'kind' => 'gift_wrap',
        'label' => 'Gift wrapping',
        'line_item_id' => line_item.prefixed_id
      )
    end
  end

  describe 'GET #show' do
    it 'returns the fee' do
      get :show, params: { order_id: order.prefixed_id, id: fee.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(fee.prefixed_id)
    end
  end
end
