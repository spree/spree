require 'spec_helper'

RSpec.describe Spree::Api::V3::Store::Carts::CouponCodesController, type: :controller do
  render_views

  include_context 'API v3 Store'

  let!(:order) { create(:order_with_line_items, store: store, user: user) }

  before do
    request.headers['X-Spree-Api-Key'] = api_key.token
    request.headers['Authorization'] = "Bearer #{jwt_token}"
  end

  describe 'POST #create' do
    context 'with a standard promotion (single code)' do
      let!(:promotion) { create(:promotion_with_item_adjustment, code: 'SAVE10', stores: [store]) }

      it 'applies the coupon code successfully' do
        post :create, params: { cart_id: order.prefixed_id, code: 'SAVE10' }

        expect(response).to have_http_status(:created)
        expect(json_response['id']).to start_with('cart_')
      end

      it 'is case insensitive' do
        post :create, params: { cart_id: order.prefixed_id, code: 'save10' }

        expect(response).to have_http_status(:created)
      end

      it 'returns error for invalid coupon code' do
        post :create, params: { cart_id: order.prefixed_id, code: 'INVALID' }

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['error']).to be_present
      end

      it 'returns error when coupon is already applied' do
        order.coupon_code = 'SAVE10'
        Spree::PromotionHandler::Coupon.new(order).apply

        post :create, params: { cart_id: order.prefixed_id, code: 'SAVE10' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with a multi-code promotion' do
      let!(:promotion) do
        create(:promotion, :with_line_item_adjustment, multi_codes: true, number_of_codes: 1, stores: [store])
      end
      let!(:coupon_code) { create(:coupon_code, promotion: promotion, code: 'multi1') }

      it 'applies the multi-code coupon successfully' do
        post :create, params: { cart_id: order.prefixed_id, code: 'multi1' }

        expect(response).to have_http_status(:created)
        expect(json_response['id']).to start_with('cart_')
      end

      it 'marks the coupon code as used' do
        post :create, params: { cart_id: order.prefixed_id, code: 'multi1' }

        expect(coupon_code.reload.state).to eq('used')
      end
    end

    context 'with a gift card' do
      let!(:gift_card) { create(:gift_card, store: store, amount: 50, code: 'giftcard123') }

      it 'applies the gift card successfully' do
        post :create, params: { cart_id: order.prefixed_id, code: 'giftcard123' }

        expect(response).to have_http_status(:created)
        expect(json_response['id']).to start_with('cart_')
      end

      it 'returns error for expired gift card' do
        gift_card.update!(expires_at: 1.day.ago)

        post :create, params: { cart_id: order.prefixed_id, code: 'giftcard123' }

        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns error for redeemed gift card' do
        gift_card.update!(state: :redeemed, redeemed_at: Time.current, amount_used: gift_card.amount)

        post :create, params: { cart_id: order.prefixed_id, code: 'giftcard123' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with expired promotion' do
      let!(:promotion) do
        create(:promotion_with_item_adjustment, code: 'EXPIRED', stores: [store],
               starts_at: 1.month.ago, expires_at: 1.day.ago)
      end

      it 'returns error' do
        post :create, params: { cart_id: order.prefixed_id, code: 'EXPIRED' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with guest spree token' do
      let(:guest_order) { create(:order_with_line_items, store: store, user: nil) }
      let!(:promotion) { create(:promotion_with_item_adjustment, code: 'GUEST10', stores: [store]) }

      before do
        request.headers['Authorization'] = nil
        request.headers['x-spree-token'] = guest_order.token
      end

      it 'allows access via spree token' do
        post :create, params: { cart_id: guest_order.prefixed_id, code: 'GUEST10' }

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'with a standard promotion' do
      let!(:promotion) { create(:promotion_with_item_adjustment, code: 'REMOVE10', stores: [store]) }

      before do
        order.coupon_code = 'REMOVE10'
        Spree::PromotionHandler::Coupon.new(order).apply
      end

      it 'removes the coupon code successfully' do
        delete :destroy, params: { cart_id: order.prefixed_id, id: 'REMOVE10' }

        expect(response).to have_http_status(:ok)
        expect(order.reload.promotions).not_to include(promotion)
      end
    end

    context 'with non-existent coupon code' do
      it 'returns error' do
        delete :destroy, params: { cart_id: order.prefixed_id, id: 'NONEXISTENT' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
