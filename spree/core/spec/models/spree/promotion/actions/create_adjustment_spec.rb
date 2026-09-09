require 'spec_helper'

describe Spree::Promotion::Actions::CreateAdjustment, type: :model do
  let(:order) { create(:order_with_line_items, line_items_count: 2) }
  let(:promotion) { create(:promotion, kind: :automatic, code: nil, store: order.store) }
  let(:action) do
    described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 4))
  end

  describe '#perform' do
    it 'distributes the order-level discount across line items' do
      expect(action.perform(order: order, promotion: promotion)).to be(true)

      rows = order.discounts.reload
      expect(rows.map(&:line_item_id)).to match_array(order.line_items.ids)
      expect(rows.sum(&:amount)).to eq(-4)
    end

    it 'reports no action at zero amount' do
      zero = described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 0))
      expect(zero.perform(order: order, promotion: promotion)).to be(false)
    end

    context 'when the promotable is a cart' do
      let(:cart) { create(:cart_with_line_items, line_items_count: 2, line_items_price: 10, store: promotion.store) }

      {
        'a flat percent of the item total' => -> { Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10) },
        'a tiered percent' => -> { Spree::Calculator::TieredPercent.new(preferred_base_percent: 10, preferred_tiers: { 100 => 50 }) },
        'a tiered flat rate' => -> { Spree::Calculator::TieredFlatRate.new(preferred_base_amount: 2, preferred_currency: 'USD', preferred_tiers: { 100 => 50 }) }
      }.each do |calculator_description, build_calculator|
        it "discounts it by #{calculator_description}" do
          action = described_class.create!(promotion: promotion, calculator: build_calculator.call)

          expect(action.perform(order: cart, promotion: promotion)).to be(true)
          expect(cart.discounts.reload.sum(&:amount)).to eq(-2)
        end
      end
    end
  end

  describe '#compute_amount' do
    it 'caps at the order total' do
      huge = described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 99_999))
      expect(huge.compute_amount(order)).to eq(-action.order_total(order))
    end
  end

  it 'has order discount scope' do
    expect(action.discount_scope).to eq(:order)
  end
end
