require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::DiscountLinesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:line_item) { order.line_items.first }
  let!(:discount_line) do
    create(:discount_line, :from_promotion, line_item: line_item, order: order, amount: -3.0)
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the order discount lines' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first).to include(
        'id' => discount_line.prefixed_id,
        'amount' => '-3.0',
        'kind' => nil,
        'line_item_id' => line_item.prefixed_id,
        'promotion_id' => discount_line.promotion.prefixed_id,
        'promotion_action_id' => discount_line.promotion_action.prefixed_id
      )
    end
  end

  describe 'GET #show' do
    it 'returns the discount line' do
      get :show, params: { order_id: order.prefixed_id, id: discount_line.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(discount_line.prefixed_id)
      expect(json_response['label']).to eq(discount_line.label)
    end
  end
end
