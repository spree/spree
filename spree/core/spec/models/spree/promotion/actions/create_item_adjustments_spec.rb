require 'spec_helper'

describe Spree::Promotion::Actions::CreateItemAdjustments, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 2) }
  let(:promotion) { create(:promotion, kind: :automatic, code: nil, stores: [order.store]) }
  let(:action) do
    described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 3))
  end

  describe '#perform' do
    it 'writes a discount per actionable line item and reports action taken' do
      expect(action.perform(order: order, promotion: promotion)).to be(true)

      rows = order.discounts.reload
      expect(rows.size).to eq(2)
      expect(rows.map(&:amount)).to all(eq(-3))
      expect(rows.map(&:promotion_action_id).uniq).to eq([action.id])
    end

    it 'is idempotent' do
      action.perform(order: order, promotion: promotion)
      action.perform(order: order, promotion: promotion)

      expect(order.discounts.reload.size).to eq(2)
    end

    it 'reports no action when nothing is actionable' do
      allow(promotion).to receive(:line_item_actionable?).and_return(false)
      expect(action.perform(order: order, promotion: promotion)).to be(false)
      expect(order.discounts.reload).to be_empty
    end
  end

  describe '#compute_amount' do
    it 'caps at the line item amount' do
      expensive = described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 999))
      allow(promotion).to receive(:line_item_actionable?).and_return(true)

      line_item = order.line_items.first
      expect(expensive.compute_amount(line_item)).to eq(-line_item.amount)
    end

    it 'returns 0 for non-actionable line items' do
      allow(promotion).to receive(:line_item_actionable?).and_return(false)
      expect(action.compute_amount(order.line_items.first)).to eq(0)
    end
  end

  it 'has line_item discount scope' do
    expect(action.discount_scope).to eq(:line_item)
  end
end
