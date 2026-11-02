require 'spec_helper'

describe Spree::Promotions::DetachFromOwner do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion_with_order_adjustment, code: 'save10', weighted_order_adjustment_amount: 10, store: store) }
  let(:cart) { create(:cart_with_line_items, line_items_count: 1, store: store) }

  before do
    cart.coupon_code = promotion.code
    Spree::PromotionHandler::Coupon.new(cart).apply
    cart.reload
  end

  it 'removes the order promotion and discounts and recalculates the cart' do
    result = described_class.call(owner: cart, promotion: promotion, clear_coupon_code: true)

    expect(result).to be_success
    cart.reload
    expect(cart.order_promotions).to be_empty
    expect(cart.discounts.promotion).to be_empty
    expect(cart.discount_total).to be_zero
    expect(cart.coupon_code).to be_nil
  end

  it 'keeps the entered code on the cart by default' do
    described_class.call(owner: cart, promotion: promotion)

    expect(cart.reload.coupon_code).to eq('save10')
  end

  it 'keeps the promotion itself' do
    described_class.call(owner: cart, promotion: promotion)

    expect(Spree::Promotion.exists?(promotion.id)).to be(true)
  end

  context 'when the owner is a completed order' do
    let(:order) { create(:completed_order_with_totals, store: store) }

    before { Spree::OrderPromotion.create!(order: order, promotion: promotion) }

    it 'fails and leaves the order alone' do
      result = described_class.call(owner: order, promotion: promotion)

      expect(result).to be_failure
      expect(order.reload.order_promotions.count).to eq(1)
    end
  end
end
