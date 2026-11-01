require 'spec_helper'

describe Spree::Promotion, type: :model do
  describe 'destroying a promotion that an open cart is using' do
    let(:store) { @default_store }
    let(:promotion) { create(:promotion_with_order_adjustment, code: 'save10', weighted_order_adjustment_amount: 10, store: store) }
    let(:cart) { create(:cart_with_line_items, line_items_count: 1, store: store) }

    before do
      cart.coupon_code = promotion.code
      Spree::PromotionHandler::Coupon.new(cart).apply
      cart.reload
    end

    it 'applies the code to the cart' do
      expect(cart.promotions).to contain_exactly(promotion)
      expect(cart.discount_total).to be_negative
    end

    it 'is allowed, because no placed order uses the promotion' do
      expect(promotion.destroy).to be_truthy
    end

    it 'leaves the cart readable' do
      promotion.destroy

      expect { cart.reload.order_promotions.map(&:name) }.not_to raise_error
    end

    it 'removes the promotion and its discount from the cart' do
      promotion.destroy
      cart.reload

      expect(cart.order_promotions).to be_empty
      expect(cart.discount_total).to be_zero
    end

    it 'is still blocked, and leaves the cart alone, when a placed order uses the promotion' do
      order = create(:completed_order_with_totals, store: store)
      Spree::OrderPromotion.create!(order: order, promotion: promotion)

      expect(promotion.destroy).to be_falsey
      expect(cart.reload.order_promotions.count).to eq(1)
      expect(cart.discount_total).to be_negative
    end
  end
end
