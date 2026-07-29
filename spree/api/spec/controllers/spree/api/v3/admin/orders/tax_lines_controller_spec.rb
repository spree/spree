require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::TaxLinesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }
  let!(:tax_line) do
    create(:tax_line, order: order, line_item: line_item, amount: 1.5, rate: 0.15, label: 'VAT 15%')
  end

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    it 'lists tax lines' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['label']).to eq('VAT 15%')
      expect(json_response['data'].first['rate']).to eq('0.15')
      expect(json_response['data'].first['line_item_id']).to eq(line_item.prefixed_id)
    end
  end

  describe 'GET #show' do
    it 'returns a tax line' do
      get :show, params: { order_id: order.prefixed_id, id: tax_line.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(tax_line.prefixed_id)
      expect(json_response['amount']).to eq('1.5')
    end
  end

  it 'does not route create' do
    expect {
      post :create, params: { order_id: order.prefixed_id }, as: :json
    }.to raise_error(ActionController::UrlGenerationError)
  end
end
