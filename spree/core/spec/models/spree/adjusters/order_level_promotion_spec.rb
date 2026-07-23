require 'spec_helper'

describe Spree::Adjusters::OrderLevelPromotion, type: :model do
  let(:order) { create(:order) }
  let!(:line_item) { create(:line_item, order: order, price: 20, quantity: 1) }

  # Order-level groups run first, then item-level competition — same order as
  # the registry default.
  def adjust_all
    adjustables = order.line_items.reload.includes(:fees, discount_lines: [:promotion, :promotion_action]).to_a +
                  order.shipments.reload.includes(:fees, discount_lines: [:promotion, :promotion_action]).to_a
    described_class.adjust_all(order, adjustables)
    Spree::Adjusters::Promotion.adjust_all(order, adjustables)
  end

  def item_promo(amount)
    promotion = create(:promotion_with_item_adjustment, adjustment_rate: amount, kind: :automatic, code: nil, store: order.store)
    promotion.actions.first.perform(order: order, promotion: promotion)
    promotion
  end

  def order_promo(amount)
    promotion = create(:promotion_with_order_adjustment, weighted_order_adjustment_amount: amount, kind: :automatic, code: nil, store: order.store)
    promotion.actions.first.perform(order: order, promotion: promotion)
    promotion
  end

  before { order.update_with_updater! }

  it 'declares the :discount type' do
    expect(described_class.type).to eq(:discount)
  end

  it 'keeps only the best order-level promotion group' do
    order_promo(4)
    best = order_promo(8)

    adjust_all

    lines = order.discount_lines.reload
    expect(lines.map(&:promotion).uniq).to eq([best])
    expect(lines.sum(&:amount)).to eq(-8)
  end

  it 'destroys groups whose promotion lost eligibility' do
    promotion = order_promo(4)
    promotion.update_columns(expires_at: 1.day.ago, starts_at: 2.days.ago)

    adjust_all

    expect(order.discount_lines.reload).to be_empty
  end

  it 'refreshes shares from one batch per action' do
    order_promo(9)
    expect_any_instance_of(Spree::Promotion::Actions::CreateAdjustment)
      .to receive(:distributed_amounts).once.and_call_original

    adjust_all
  end

  it 'stacks with item-level promotions on the same line item' do
    item_promo(5)
    order_promo(4)

    adjust_all

    lines = line_item.discount_lines.reload
    expect(lines.count).to eq(2)
    expect(lines.sum(&:amount)).to eq(-9)
  end
end
