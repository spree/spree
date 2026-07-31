require 'spec_helper'

describe Spree::Adjusters::Promotion, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 2) }
  let(:store) { order.store }

  def line_promo(rate, code: nil)
    kind = code ? :coupon_code : :automatic
    create(:promotion_with_item_adjustment, adjustment_rate: rate, code: code, kind: kind, store: store)
  end

  it 'writes a discount row per line item for an applied promotion' do
    promo = line_promo(5)
    promo.activate(order: order)

    rows = order.discounts.reload
    expect(rows.size).to eq(2)
    expect(rows.map(&:amount)).to all(eq(-5))
    expect(rows.map(&:kind).uniq).to eq(['promotion'])
    expect(rows.map(&:promotion_id).uniq).to eq([promo.id])
  end

  it 'keeps only the winning promotion per line item' do
    weak = line_promo(2)
    strong = line_promo(7)
    weak.activate(order: order)
    strong.activate(order: order)
    described_class.adjust(order)

    rows = order.discounts.reload
    expect(rows.map(&:promotion_id).uniq).to eq([strong.id])
    expect(rows.map(&:amount)).to all(eq(-7))
  end

  it 'reinstates the losing promotion when the winner stops being eligible' do
    weak = line_promo(2)
    strong = line_promo(7)
    weak.activate(order: order)
    strong.activate(order: order)
    described_class.adjust(order)

    strong.update!(expires_at: 1.day.ago, starts_at: 2.days.ago)
    described_class.adjust(order)

    rows = order.discounts.reload
    expect(rows.map(&:promotion_id).uniq).to eq([weak.id])
    expect(rows.map(&:amount)).to all(eq(-2))
  end

  it 'removes rows whose promotion was deleted' do
    promo = line_promo(5)
    promo.activate(order: order)
    expect(order.discounts.reload.size).to eq(2)

    promo.promotion_actions.each { |action| action.update_column(:deleted_at, Time.current) }
    order.order_promotions.destroy_all
    described_class.adjust(order)

    expect(order.discounts.reload).to be_empty
  end

  it 'clamps so a line never goes below zero' do
    promo = create(:promotion, kind: :automatic, code: nil, store: store)
    action = Spree::Promotion::Actions::CreateItemAdjustments.create!(
      promotion: promo,
      calculator: Spree::Calculator::FlatRate.new(preferred_amount: 999)
    )
    promo.activate(order: order)

    order.discounts.reload.each do |row|
      expect(row.amount).to eq(-row.line_item.amount)
    end
    expect(action.reload).to be_present
  end

  describe 'order-level distribution' do
    let(:order) { create(:order_with_line_items, line_items_count: 3) }

    it 'distributes the winner across line items with largest-remainder' do
      promo = create(:promotion_with_order_adjustment, weighted_order_adjustment_amount: 10, code: nil, kind: :automatic, store: store)
      promo.activate(order: order)

      rows = order.discounts.reload
      expect(rows.size).to eq(3)
      expect(rows.sum(&:amount)).to eq(-10)
      expect(rows.map(&:line_item_id)).to match_array(order.line_items.ids)
    end

    it 'never distributes more than the remaining line bases' do
      promo = create(:promotion_with_order_adjustment, weighted_order_adjustment_amount: 9_999, code: nil, kind: :automatic, store: store)
      promo.activate(order: order)

      expect(order.discounts.reload.sum(&:amount)).to eq(-order.line_items.sum(&:amount))
    end
  end

  describe 'free shipping' do
    let(:order) { create(:order_with_line_items, line_items_count: 1) }

    it 'persists a fulfillment discount even at zero cost' do
      order.fulfillments.each { |fulfillment| fulfillment.update_column(:cost, 0) }
      promo = create(:free_shipping_promotion, code: nil, kind: :automatic, store: store)
      promo.activate(order: order)

      rows = order.discounts.reload.select(&:fulfillment_id)
      expect(rows.size).to eq(order.fulfillments.count)
      expect(rows.map(&:amount)).to all(eq(0))
      expect(order.has_free_shipping?).to be(true)
    end
  end
end
