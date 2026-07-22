require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment, type: :model do
  let(:order) { create(:order) }
  let(:promotion) { create(:promotion, kind: :automatic) }
  let(:action) { described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 10)) }
  let(:payload) { { order: order, promotion: promotion } }

  describe '#perform' do
    let!(:line_item) { create(:line_item, order: order, price: 30, quantity: 1) }

    before { order.update_with_updater! }

    it 'does not write a discount line if the amount is 0' do
      action.calculator.preferred_amount = 0

      expect(action.perform(payload)).to be(false)
      expect(order.discount_lines).to be_empty
    end

    it 'distributes the discount to line items with a negative amount' do
      expect(action.perform(payload)).to be(true)

      expect(order.discount_lines.count).to eq(1)
      expect(order.discount_lines.first.amount).to eq(-10)
      expect(order.discount_lines.first.line_item).to eq(line_item)
      expect(order.discount_lines.first.promotion).to eq(promotion)
    end

    it 'is idempotent — a second perform updates rather than duplicates' do
      action.perform(payload)
      action.perform(payload)

      expect(order.discount_lines.count).to eq(1)
    end

    it 'clamps the discount to the order total' do
      action.calculator.preferred_amount = 100

      action.perform(payload)

      expect(order.discount_lines.sum(:amount)).to eq(-30)
    end
  end

  describe 'proportional distribution' do
    let!(:small_item) { create(:line_item, order: order, price: 10, quantity: 1) }
    let!(:big_item) { create(:line_item, order: order, price: 20, quantity: 1) }

    before { order.update_with_updater! }

    it 'splits by line item amount, remainder to the largest fraction' do
      action.perform(payload)

      expect(small_item.discount_lines.sum(:amount)).to eq(BigDecimal('-3.33'))
      expect(big_item.discount_lines.sum(:amount)).to eq(BigDecimal('-6.67'))
      expect(order.discount_lines.sum(:amount)).to eq(-10)
    end

    it 'always sums exactly to the promotion amount across equal thirds' do
      thirds_order = create(:order)
      3.times { create(:line_item, order: thirds_order, price: 10, quantity: 1) }
      thirds_order.update_with_updater!

      action.perform(order: thirds_order, promotion: promotion)

      shares = thirds_order.discount_lines.order(:line_item_id).pluck(:amount)
      expect(shares.sum).to eq(-10)
      expect(shares).to contain_exactly(BigDecimal('-3.33'), BigDecimal('-3.33'), BigDecimal('-3.34'))
    end

    it 'splits sevenths deterministically — remainder cents go to the lowest line item ids' do
      sevenths_order = create(:order)
      7.times { create(:line_item, order: sevenths_order, price: 10, quantity: 1) }
      sevenths_order.update_with_updater!

      action.perform(order: sevenths_order, promotion: promotion)

      # -1000 cents / 7 = -142.857… each: all fractional remainders are equal,
      # so the 6 leftover cents land on the 6 lowest ids (tie-break)
      shares = sevenths_order.discount_lines.order(:line_item_id).pluck(:amount)
      expect(shares.sum).to eq(-10)
      expect(shares).to eq([BigDecimal('-1.43')] * 6 + [BigDecimal('-1.42')])
    end

    it 'stays exact and proportional on an irregular cart' do
      irregular_order = create(:order)
      [[19.99, 1], [7.77, 3], [3.33, 1], [42.00, 2], [0.99, 5], [13.13, 1], [5.55, 2]].each do |price, quantity|
        create(:line_item, order: irregular_order, price: price, quantity: quantity)
      end
      irregular_order.update_with_updater!
      action.calculator.preferred_amount = 17.53

      action.perform(order: irregular_order, promotion: promotion)

      lines = irregular_order.discount_lines.includes(:line_item)
      item_total = irregular_order.line_items.sum(&:amount)

      expect(lines.sum(:amount)).to eq(BigDecimal('-17.53'))
      lines.each do |line|
        exact_share = BigDecimal('-17.53') * line.line_item.amount / item_total
        expect(line.amount).to be_negative
        expect((line.amount - exact_share).abs).to be < BigDecimal('0.01')
        expect(action.compute_amount(line.line_item)).to eq(line.amount)
      end
    end

    it 'distributes even a single cent' do
      action.calculator.preferred_amount = 0.01

      action.perform(payload)

      expect(order.discount_lines.sum(:amount)).to eq(BigDecimal('-0.01'))
      expect(order.discount_lines.count).to eq(1)
    end

    it 'reproduces the same share at recomputation time' do
      action.perform(payload)

      order.discount_lines.each do |line|
        expect(action.compute_amount(line.line_item)).to eq(line.amount)
      end
    end
  end

  describe '#compute_amount' do
    let!(:line_item) { create(:line_item, order: order, price: 30, quantity: 1) }

    before { order.update_with_updater! }

    it 'returns the full discount when the order has a single line item' do
      expect(action.compute_amount(line_item.reload)).to eq(-10)
    end

    it 'caps the discount at the order total' do
      action.calculator.preferred_amount = 100

      expect(action.compute_amount(line_item.reload)).to eq(-30)
    end

    it 'returns 0 for a line item without a computable share' do
      other_order_item = create(:line_item, price: 0, quantity: 1)

      expect(action.compute_amount(other_order_item)).to eq(0)
    end
  end

  describe '#order_total' do
    it 'sums item and shipping totals net of shipping discounts' do
      order = double(:order, item_total: 30, ship_total: 10, shipping_discount: 10)

      expect(described_class.new.order_total(order)).to eq(30)
    end
  end

  describe 'destroying the action' do
    let!(:line_item) { create(:line_item, order: order, price: 30, quantity: 1) }

    before { order.update_with_updater! }

    it 'removes its discount lines from incomplete orders' do
      action.perform(payload)
      expect(order.discount_lines.count).to eq(1)

      action.destroy!

      expect(order.discount_lines.reload).to be_empty
    end

    it 'keeps discount lines on completed orders' do
      action.perform(payload)
      order.update_columns(completed_at: Time.current, state: 'complete')

      action.destroy!

      expect(order.discount_lines.reload.count).to eq(1)
      expect(order.discount_lines.first.promotion_action).to eq(action)
    end
  end
end
