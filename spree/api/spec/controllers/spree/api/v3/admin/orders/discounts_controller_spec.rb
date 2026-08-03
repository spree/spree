require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::DiscountsController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let!(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }

  before { request.headers.merge!(headers) }

  describe 'GET #index' do
    let!(:manual_discount) do
      create(:discount, order: order, line_item: line_item, amount: -2, label: 'Loyalty', kind: 'manual')
    end

    it 'lists typed discount rows' do
      get :index, params: { order_id: order.prefixed_id }, as: :json

      expect(response).to have_http_status(:ok)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['label']).to eq('Loyalty')
      expect(json_response['data'].first['kind']).to eq('manual')
      expect(json_response['data'].first['line_item_id']).to eq(line_item.prefixed_id)
    end
  end

  describe 'POST #create' do
    it 'creates a line-item discount and re-sums totals' do
      original_total = order.total

      post :create, params: {
        order_id: order.prefixed_id,
        line_item_id: line_item.prefixed_id,
        label: 'Appeasement',
        value: 3,
        value_type: 'flat'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['data'].length).to eq(1)
      expect(json_response['data'].first['amount']).to eq('-3.0')
      expect(order.reload.total).to eq(original_total - 3)
    end

    it 'distributes an order-level discount across line items' do
      post :create, params: {
        order_id: order.prefixed_id,
        label: 'Order apology',
        value: 4,
        value_type: 'flat'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(json_response['data'].sum { |row| BigDecimal(row['amount']) }).to eq(-4)
      expect(json_response['data']).to all(include('kind' => 'manual'))
    end

    it 'supports percent discounts' do
      post :create, params: {
        order_id: order.prefixed_id,
        line_item_id: line_item.prefixed_id,
        label: 'Percent off',
        value: 50,
        value_type: 'percent'
      }, as: :json

      expect(response).to have_http_status(:created)
      expect(BigDecimal(json_response['data'].first['amount'])).to eq(-(line_item.amount / 2).round(2))
    end

    it 'rejects a non-positive value' do
      post :create, params: { order_id: order.prefixed_id, label: 'Bad', value: -5 }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'PATCH #update' do
    let!(:manual_discount) do
      create(:discount, order: order, line_item: line_item, amount: -2, label: 'Loyalty', kind: 'manual')
    end

    it 'updates a manual discount' do
      patch :update, params: { order_id: order.prefixed_id, id: manual_discount.prefixed_id, label: 'Renamed' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(manual_discount.reload.label).to eq('Renamed')
    end

    it 'refuses to edit promotion-sourced rows' do
      manual_discount.update_columns(kind: 'promotion')

      patch :update, params: { order_id: order.prefixed_id, id: manual_discount.prefixed_id, label: 'Nope' }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json_response['error']['code']).to eq('discount_not_editable')
    end
  end

  describe 'DELETE #destroy' do
    let!(:manual_discount) do
      create(:discount, order: order, line_item: line_item, amount: -2, label: 'Loyalty', kind: 'manual')
    end

    it 'removes the row and re-sums totals' do
      order.recalculate_totals!
      with_discount_total = order.reload.total

      delete :destroy, params: { order_id: order.prefixed_id, id: manual_discount.prefixed_id }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(order.reload.total).to eq(with_discount_total + 2)
      expect(Spree::Discount.exists?(manual_discount.id)).to be(false)
    end
  end
end
