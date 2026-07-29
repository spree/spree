require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::FeesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:fee) { create(:fee, order: order, amount: 5, label: 'Handling', kind: 'handling') }

    it 'lists fee rows' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['label']).to eq('Handling')
      expect(json_response['data'].first['amount']).to eq('5.0')
    end
  end

  describe 'POST #create' do
    it 'creates an order-level fee and re-sums totals' do
      original_total = order.total

      post :create, params: { order_id: order.prefixed_id, label: 'Gift wrap', amount: 4, kind: 'gift_wrap' }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['label']).to eq('Gift wrap')
      expect(json_response['line_item_id']).to be_nil
      expect(order.reload.total).to eq(original_total + 4)
      expect(order.fee_total).to eq(4)
    end

    it 'creates a line-item fee' do
      post :create, params: {
        order_id: order.prefixed_id, line_item_id: line_item.prefixed_id, label: 'Restocking', amount: 2
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['line_item_id']).to eq(line_item.prefixed_id)
      expect(json_response['kind']).to eq('surcharge')
    end

    it 'rejects a negative amount' do
      post :create, params: { order_id: order.prefixed_id, label: 'Credit', amount: -3 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let!(:fee) { create(:fee, order: order, amount: 5, label: 'Handling', kind: 'handling') }

    it 'updates the fee and re-sums totals' do
      order.updater.resum_typed_totals!
      with_fee_total = order.reload.total

      patch :update, params: { order_id: order.prefixed_id, id: fee.prefixed_id, amount: 8 }, as: :json

      expect(response).to have_http_status(:ok)
      expect(fee.reload.amount).to eq(8)
      expect(order.reload.total).to eq(with_fee_total + 3)
    end
  end

  describe 'DELETE #destroy' do
    let!(:fee) { create(:fee, order: order, amount: 5, label: 'Handling', kind: 'handling') }

    it 'removes the fee and re-sums totals' do
      order.updater.resum_typed_totals!
      with_fee_total = order.reload.total

      delete :destroy, params: { order_id: order.prefixed_id, id: fee.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(order.reload.total).to eq(with_fee_total - 5)
    end
  end
end
