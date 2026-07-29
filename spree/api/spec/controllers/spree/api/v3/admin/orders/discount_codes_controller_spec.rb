require 'spec_helper'

RSpec.describe Spree::Api::V3::Admin::Orders::DiscountCodesController, type: :controller do
  render_views

  include_context 'API v3 Admin authenticated'

  let(:store) { @default_store }
  let!(:promotion) do
    create(:promotion_with_item_total_rule, :with_line_item_adjustment,
           code: 'save5', kind: :coupon_code, store: store,
           item_total_threshold_amount: 30, adjustment_rate: 5)
  end

  before { request.headers.merge!(headers) }

  describe 'POST #create' do
    context 'with a qualifying draft order' do
      let(:order) { create(:order_with_line_items, store: store, line_items_price: 50) }

      it 'applies the code and returns the order' do
        post :create, params: { order_id: order.prefixed_id, code: 'SAVE5' }, as: :json

        expect(response).to have_http_status(:created)
        expect(json_response['coupon_code']).to eq('save5')
        expect(order.reload.discounts.where(promotion_id: promotion.id)).to be_present
      end
    end

    context 'with a draft order below the promotion threshold' do
      let(:order) { create(:order_with_line_items, store: store, line_items_price: 10) }

      it 'keeps the code pending without discount rows' do
        post :create, params: { order_id: order.prefixed_id, code: 'save5' }, as: :json

        expect(response).to have_http_status(:created)
        expect(order.reload.read_attribute(:coupon_code)).to eq('save5')
        expect(order.discounts.where(promotion_id: promotion.id)).to be_empty
      end
    end

    context 'with an unknown code' do
      let(:order) { create(:order_with_line_items, store: store, line_items_price: 50) }

      it 'rejects and does not persist the code' do
        post :create, params: { order_id: order.prefixed_id, code: 'bogus' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(order.reload.read_attribute(:coupon_code)).to be_nil
      end
    end

    context 'with a completed order' do
      let(:order) { create(:completed_order_with_totals, store: store) }

      it 'refuses — completed orders take manual discounts only' do
        post :create, params: { order_id: order.prefixed_id, code: 'save5' }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']['code']).to eq('discount_not_editable')
      end
    end
  end

  describe 'DELETE #destroy' do
    let(:order) { create(:order_with_line_items, store: store, line_items_price: 50) }

    it 'removes the promotion and clears the stored code' do
      order.update!(coupon_code: 'save5')
      order.update_with_updater!
      expect(order.reload.discounts.where(promotion_id: promotion.id)).to be_present

      delete :destroy, params: { order_id: order.prefixed_id, id: 'save5' }, as: :json

      expect(response).to have_http_status(:ok)
      expect(order.reload.read_attribute(:coupon_code)).to be_nil
      expect(order.discounts.where(promotion_id: promotion.id)).to be_empty
    end
  end
end
