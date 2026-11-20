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

    context 'when a rule excludes one of the products' do
      let(:order) { create(:order_with_line_items, line_items_count: 2, line_items_price: 30) }
      let(:excluded_line_item) { order.line_items.first }
      let(:action) do
        described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 10))
      end

      before do
        excluded_line_item.update_column(:price, 70)
        create(:promotion_rule_product, promotion: promotion, preferred_match_policy: 'none',
                                        product_ids_to_add: [excluded_line_item.product_id])
        promotion.reload
      end

      it 'takes the percentage of the other lines and lands it on them only' do
        action.perform(order: order, promotion: promotion)

        rows = order.discounts.reload
        expect(rows.map(&:line_item_id)).to eq([order.line_items.last.id])
        expect(rows.sum(&:amount)).to eq(-3)
      end

      # An exclusion never qualifies an order on its own, so it cannot widen
      # a promotion whose rules only need one match.
      it 'does not count the exclusion towards an any-rule match' do
        promotion.update!(match_policy: 'any')
        create(:promotion_rule_taxon, promotion: promotion, preferred_match_policy: 'any',
                                      category_ids_to_add: [create(:category).id])
        promotion.reload

        expect(action.perform(order: order, promotion: promotion)).to be(false)
        expect(order.discounts.reload).to be_empty
      end
    end

    it 'leaves a line whose product is not discountable out of the discount' do
      order.line_items.first.product.update_column(:promotionable, false)

      action.perform(order: order, promotion: promotion)

      rows = order.discounts.reload
      expect(rows.map(&:line_item_id)).to eq([order.line_items.last.id])
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
        'a tiered percent' => -> { Spree::Calculator::TieredPercent.new(preferred_base_percent: 10, preferred_tiers: [{ threshold: 100, value: 50 }]) },
        'a tiered flat rate' => -> { Spree::Calculator::TieredFlatRate.new(preferred_base_amount: 2, preferred_currency: 'USD', preferred_tiers: [{ threshold: 100, value: 50 }]) }
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

    context 'when a line is excluded' do
      let(:excluded_line_item) { order.line_items.first }

      before do
        allow(promotion).to receive(:excludes_line_item?) { |line_item| line_item.id == excluded_line_item.id }
      end

      it 'never turns the cap into a charge' do
        huge = described_class.create!(promotion: promotion, calculator: Spree::Calculator::FlatRate.new(preferred_amount: 99_999))
        allow(huge).to receive(:order_total).and_return(BigDecimal(5))

        expect(huge.compute_amount(order)).to eq(0)
      end

      # The order amount calculators see already leaves gift units out, so a
      # gifted excluded line must not be taken off a second time.
      it 'takes a gifted excluded line out once' do
        half_off = described_class.create!(promotion: promotion,
                                           calculator: Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: 50))
        allow(order).to receive(:gift_amount).and_return(excluded_line_item.amount)

        expect(half_off.compute_amount(order)).to eq(-order.line_items.last.amount / 2)
      end
    end
  end

  describe Spree::Promotion::Actions::CreateAdjustment::DiscountableOrder do
    let(:discountable_order) { described_class.new(order, BigDecimal(5)) }

    it 'reports the order amount less the excluded lines' do
      expect(discountable_order.amount).to eq(order.amount - 5)
    end

    it 'answers as the order it wraps, so calculators dispatch on it' do
      expect(discountable_order.class).to eq(Spree::Order)
      expect(discountable_order).to be_a(Spree::Order)
    end
  end
end
