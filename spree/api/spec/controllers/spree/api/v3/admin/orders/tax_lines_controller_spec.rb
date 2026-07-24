require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::TaxLinesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:order_with_line_items, store: store, line_items_count: 1) }
  let(:line_item) { order.line_items.first }
  let!(:tax_line) { create(:tax_line, line_item: line_item, order: order, amount: 2.5, label: 'VAT') }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'returns the order tax lines' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first).to include(
        'id' => tax_line.prefixed_id,
        'amount' => '2.5',
        'label' => 'VAT',
        'included' => false,
        'line_item_id' => line_item.prefixed_id,
        'fulfillment_id' => nil,
        'tax_rate_id' => tax_line.tax_rate.prefixed_id
      )
    end
  end

  describe 'GET #show' do
    it 'returns the tax line' do
      get :show, params: { order_id: order.prefixed_id, id: tax_line.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(tax_line.prefixed_id)
      expect(json_response['order_id']).to eq(order.prefixed_id)
    end

    it 'does not find tax lines of other orders' do
      other = create(:tax_line, line_item: create(:order_with_line_items, store: store).line_items.first)

      get :show, params: { order_id: order.prefixed_id, id: other.prefixed_id }, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
