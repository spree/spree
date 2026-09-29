require 'spec_helper'

# The persisted cart coupon code keeps its promotion in adjuster candidacy:
# the discount activates on the recalculation where the cart first qualifies
# and deactivates the same way (docs/plans review 2026-07-29).
describe 'coupon code retry on recalculation' do
  let(:store) { @default_store }
  let!(:promotion) do
    create(:promotion_with_item_total_rule, :with_line_item_adjustment,
           code: 'save5', kind: :coupon_code, store: store,
           item_total_threshold_amount: 30, adjustment_rate: 5)
  end
  let(:cart) { create(:cart_with_line_items, store: store, line_items_price: 10) }

  it 'activates the pending code once the cart qualifies and deactivates below threshold' do
    cart.update!(coupon_code: 'save5')
    cart.recalculate_totals!
    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_empty

    # Grow the cart past the threshold — recalculation applies the code.
    create(:line_item, cart: cart, order: nil, price: 25)
    cart.line_items.reload
    cart.recalculate_totals!

    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_present
    expect(cart.order_promotions.where(promotion_id: promotion.id)).to be_present

    # Shrink below the threshold — rows deactivate, the code stays.
    cart.line_items.order(:created_at).last.destroy!
    cart.line_items.reload
    cart.recalculate_totals!

    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_empty
    expect(cart.read_attribute(:coupon_code)).to eq('save5')
  end

  it 'clears the persisted code when the promotion is removed' do
    cart.line_items.first.update!(price: 50)
    cart.update!(coupon_code: 'save5')
    cart.recalculate_totals!
    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_present

    handler = Spree::PromotionHandler::Coupon.new(cart)
    handler.remove('save5')

    expect(handler.successful?).to be(true)
    expect(cart.reload.read_attribute(:coupon_code)).to be_nil
    expect(cart.discounts.where(promotion_id: promotion.id)).to be_empty
  end

  context 'with a batch of single-use codes' do
    let!(:promotion) do
      create(:promotion_with_item_total_rule, :with_order_adjustment,
             code: nil, multi_codes: true, number_of_codes: 2, kind: :coupon_code, store: store,
             item_total_threshold_amount: 30, weighted_order_adjustment_amount: 5)
    end
    let(:coupon_code) { promotion.coupon_codes.first }
    let(:other_cart) { create(:cart_with_line_items, store: store, line_items_price: 10) }

    def apply_code(owner)
      owner.update!(coupon_code: coupon_code.code)
      Spree::PromotionHandler::Coupon.new(owner).apply
    end

    def qualify(owner)
      create(:line_item, cart: owner, order: nil, price: 25)
      owner.line_items.reload
      owner.recalculate_totals!
    end

    it 'holds a code saved before the cart qualifies' do
      expect(apply_code(cart).status_code).to eq(:coupon_code_not_eligible)
      expect(coupon_code.reload.holder).to eq(cart)

      qualify(cart)

      expect(cart.reload.discount_total).to eq(-5)
    end

    it 'discounts only the cart that presented the code last' do
      apply_code(cart)
      apply_code(other_cart)

      qualify(cart)
      qualify(other_cart)

      expect(coupon_code.reload.holder).to eq(other_cart)
      expect(cart.reload.discount_total).to be_zero
      expect(other_cart.reload.discount_total).to eq(-5)
    end

    it 'never discounts a cart saving the code without holding it' do
      cart.update!(coupon_code: coupon_code.code)

      qualify(cart)

      expect(cart.reload.discount_total).to be_zero
    end

    it 'gives back a code saved before the cart qualified once another replaces it' do
      apply_code(cart)
      replacement = promotion.coupon_codes.second
      cart.update!(coupon_code: replacement.code)
      Spree::PromotionHandler::Coupon.new(cart).apply

      expect(coupon_code.reload.holder).to be_nil
      expect(replacement.reload.holder).to eq(cart)
    end

    it 'does not treat a code nobody holds as taken' do
      cart.update!(coupon_code: coupon_code.code)

      expect(cart.coupon_code_taken?).to be(false)

      coupon_code.update!(cart: other_cart)

      expect(cart.coupon_code_taken?).to be(true)
    end

    it 'lets the shopper remove a code saved before the cart qualified' do
      apply_code(cart)

      handler = Spree::PromotionHandler::Coupon.new(cart).remove(coupon_code.code)

      expect(handler.successful?).to be(true)
      expect(cart.reload.read_attribute(:coupon_code)).to be_nil
      expect(coupon_code.reload.holder).to be_nil
    end
  end
end
