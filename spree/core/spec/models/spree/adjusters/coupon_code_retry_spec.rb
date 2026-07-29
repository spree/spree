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
    cart.update_with_updater!
    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_empty

    # Grow the cart past the threshold — recalculation applies the code.
    create(:line_item, cart: cart, order: nil, price: 25)
    cart.line_items.reload
    cart.update_with_updater!

    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_present
    expect(cart.order_promotions.where(promotion_id: promotion.id)).to be_present

    # Shrink below the threshold — rows deactivate, the code stays.
    cart.line_items.order(:created_at).last.destroy!
    cart.line_items.reload
    cart.update_with_updater!

    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_empty
    expect(cart.read_attribute(:coupon_code)).to eq('save5')
  end

  it 'clears the persisted code when the promotion is removed' do
    cart.line_items.first.update!(price: 50)
    cart.update!(coupon_code: 'save5')
    cart.update_with_updater!
    expect(cart.reload.discounts.where(promotion_id: promotion.id)).to be_present

    handler = Spree::PromotionHandler::Coupon.new(cart)
    handler.remove('save5')

    expect(handler.successful?).to be(true)
    expect(cart.reload.read_attribute(:coupon_code)).to be_nil
    expect(cart.discounts.where(promotion_id: promotion.id)).to be_empty
  end
end
