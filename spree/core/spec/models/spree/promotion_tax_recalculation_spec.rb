require 'spec_helper'

# Covers the discount x calculator x tax-mode matrix of the promotion /
# taxable-basis bug: applying any promotion must move the taxable basis, for
# line-item and whole-order adjustments, percent and flat-rate calculators,
# additional (US-style) and included (VAT-style) tax — and the corrected
# figures must survive the checkout tax rebuild (create_tax_charge!) that
# writes the totals persisted onto completed orders.
describe 'Promotion discounts and the taxable basis', type: :model do
  let(:store) { @default_store }
  let(:tax_category) { create(:tax_category) }

  let!(:zone) do
    create(:zone, name: 'Default tax zone', kind: 'country', default_tax: true).tap do |zone|
      zone.zone_members.create!(zoneable: @default_country)
    end
  end

  let(:product) { create(:product, price: item_price, tax_category: tax_category, store: store) }
  let(:order) { create(:order, store: store, currency: 'USD') }
  # Lazy on purpose: the tax rate must exist before the line item is created,
  # because Spree only creates tax adjustments from LineItem#update_tax_charge.
  # Each tax-mode context forces it in a before hook after its tax rate.
  let(:line_item) { create(:line_item, order: order, variant: product.master, price: item_price, quantity: 1) }

  def build_cart!
    line_item
    # the order instance may hold a stale (empty) cached line_items association
    order.reload
    order.update_with_updater!
    order.reload
  end

  def line_item_promotion(calculator)
    create(:promotion, code: 'DISCOUNT', store: store).tap do |promotion|
      Spree::Promotion::Actions::CreateItemAdjustments.create!(calculator: calculator, promotion: promotion)
    end
  end

  def whole_order_promotion(calculator)
    create(:promotion, code: 'DISCOUNT', store: store).tap do |promotion|
      Spree::Promotion::Actions::CreateAdjustment.create!(calculator: calculator, promotion: promotion)
    end
  end

  def apply_coupon!
    order.coupon_code = 'DISCOUNT'
    handler = Spree::PromotionHandler::Coupon.new(order).apply
    expect(handler.successful?).to be(true), "coupon was not applied: #{handler.error}"
    order.reload
  end

  # The checkout state machine rebuilds all tax adjustments through
  # Spree::TaxRate.adjust before payment; whatever it computes is what a
  # completed order keeps.
  def rebuild_tax_like_checkout!
    order.create_tax_charge!
    order.update_with_updater!
    order.reload
  end

  def percent_calculator(percent)
    Spree::Calculator::PercentOnLineItem.new(preferred_percent: percent)
  end

  def flat_calculator(amount)
    Spree::Calculator::FlatRate.new(preferred_amount: amount)
  end

  def flat_percent_calculator(percent)
    Spree::Calculator::FlatPercentItemTotal.new(preferred_flat_percent: percent)
  end

  context 'with additional (US-style) tax of 10%' do
    let(:item_price) { 250 }
    let!(:tax_rate) do
      create(:tax_rate, zone: zone, tax_category: tax_category, amount: 0.10, included_in_price: false)
    end

    before { build_cart! }

    it 'starts from tax on the full amount' do
      expect(order.additional_tax_total).to eq(25.00)
      expect(order.total).to eq(275.00)
    end

    context 'with a 50% line-item promotion' do
      let!(:promotion) { line_item_promotion(percent_calculator(50)) }

      it 'computes tax on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-125.00)
        expect(order.additional_tax_total).to eq(12.50)
        expect(order.total).to eq(137.50)
      end
    end

    context 'with a flat 50 line-item promotion' do
      let!(:promotion) { line_item_promotion(flat_calculator(50)) }

      it 'computes tax on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-50.00)
        expect(order.additional_tax_total).to eq(20.00)
        expect(order.total).to eq(220.00)
      end
    end

    context 'with a 50% whole-order promotion' do
      let!(:promotion) { whole_order_promotion(flat_percent_calculator(50)) }

      it 'computes tax on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-125.00)
        expect(order.additional_tax_total).to eq(12.50)
        expect(order.total).to eq(137.50)
      end

      it 'keeps the discounted tax through the checkout tax rebuild' do
        apply_coupon!
        rebuild_tax_like_checkout!

        expect(order.additional_tax_total).to eq(12.50)
        expect(order.total).to eq(137.50)
      end
    end

    context 'with a flat 50 whole-order promotion' do
      let!(:promotion) { whole_order_promotion(flat_calculator(50)) }

      it 'computes tax on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-50.00)
        expect(order.additional_tax_total).to eq(20.00)
        expect(order.total).to eq(220.00)
      end
    end

    context 'with a whole-order promotion and several line items' do
      let(:other_product) { create(:product, price: 150, tax_category: tax_category, store: store) }
      let!(:other_line_item) do
        create(:line_item, order: order, variant: other_product.master, price: 150, quantity: 1)
      end
      let!(:promotion) { whole_order_promotion(flat_calculator(80)) }

      it 'allocates the discount across line items proportionally' do
        apply_coupon!

        # 400 total, discount 80 -> line bases 200 and 120
        expect(line_item.reload.additional_tax_total).to eq(20.00)
        expect(other_line_item.reload.additional_tax_total).to eq(12.00)
        expect(order.additional_tax_total).to eq(32.00)
        expect(order.total).to eq(352.00)
      end
    end
  end

  context 'with included (VAT-style) tax of 20%' do
    let(:item_price) { 350 }
    let!(:tax_rate) do
      create(:tax_rate, zone: zone, tax_category: tax_category, amount: 0.20, included_in_price: true)
    end

    before { build_cart! }

    it 'starts from VAT on the full amount' do
      expect(order.included_tax_total).to eq(58.33)
      expect(order.total).to eq(350.00)
    end

    context 'with a 50% line-item promotion' do
      let!(:promotion) { line_item_promotion(percent_calculator(50)) }

      it 'reports VAT on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-175.00)
        expect(order.included_tax_total).to eq(29.17)
        expect(order.total).to eq(175.00)
      end

      it 'keeps the discounted VAT through the checkout tax rebuild' do
        apply_coupon!
        rebuild_tax_like_checkout!

        expect(order.included_tax_total).to eq(29.17)
        expect(order.total).to eq(175.00)
      end
    end

    context 'with a flat 50 line-item promotion' do
      let!(:promotion) { line_item_promotion(flat_calculator(50)) }

      it 'reports VAT on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-50.00)
        expect(order.included_tax_total).to eq(50.00)
        expect(order.total).to eq(300.00)
      end
    end

    context 'with a 50% whole-order promotion' do
      let!(:promotion) { whole_order_promotion(flat_percent_calculator(50)) }

      it 'reports VAT on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-175.00)
        expect(order.included_tax_total).to eq(29.17)
        expect(order.total).to eq(175.00)
      end

      it 'keeps the discounted VAT through the checkout tax rebuild' do
        apply_coupon!
        rebuild_tax_like_checkout!

        expect(order.included_tax_total).to eq(29.17)
        expect(order.total).to eq(175.00)
      end
    end

    context 'with a flat 50 whole-order promotion' do
      let!(:promotion) { whole_order_promotion(flat_calculator(50)) }

      it 'reports VAT on the discounted amount' do
        apply_coupon!

        expect(order.promo_total).to eq(-50.00)
        expect(order.included_tax_total).to eq(50.00)
        expect(order.total).to eq(300.00)
      end
    end

    context 'when the promotion is removed again' do
      let!(:promotion) { whole_order_promotion(flat_percent_calculator(50)) }

      it 'restores VAT on the full amount' do
        apply_coupon!
        Spree::PromotionHandler::Coupon.new(order).remove('DISCOUNT')
        order.reload

        expect(order.promo_total).to eq(0)
        expect(order.included_tax_total).to eq(58.33)
        expect(order.total).to eq(350.00)
      end
    end
  end
end
