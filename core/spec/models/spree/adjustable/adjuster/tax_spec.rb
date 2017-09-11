require 'spec_helper'

describe Spree::Adjustable::Adjuster::Tax, type: :model do
  let(:order) { create :order_with_line_items, line_items_count: 1 }
  let(:line_item) { order.line_items.first }

  let(:subject) { Spree::Adjustable::AdjustmentsUpdater.new(line_item) }
  let(:order_subject) { Spree::Adjustable::AdjustmentsUpdater.new(order) }

  context 'taxes with promotions' do
    let!(:tax_rate) do
      create(:tax_rate, amount: 0.05)
    end

    let!(:promotion) do
      Spree::Promotion.create(name: '$10 off')
    end

    let!(:promotion_action) do
      calculator = Spree::Calculator::FlatRate.new(preferred_amount: 10)
      Spree::Promotion::Actions::CreateItemAdjustments.create(calculator: calculator,
                                                              promotion: promotion)
    end

    before do
      line_item.price = 20
      line_item.tax_category = tax_rate.tax_category
      line_item.save
      create(:adjustment, order: order, source: promotion_action, adjustable: line_item)
    end

    context 'tax included in price' do
      before do
        create(:adjustment,
               source: tax_rate,
               adjustable: line_item,
               order: order,
               included: true)
      end

      it 'tax has no bearing on final price' do
        subject.update
        line_item.reload
        expect(line_item.included_tax_total).to eq(0.5)
        expect(line_item.additional_tax_total).to eq(0)
        expect(line_item.promo_total).to eq(-10)
        expect(line_item.adjustment_total).to eq(-10)
      end

      it 'tax linked to order' do
        order_subject.update
        order.reload
        expect(order.included_tax_total).to eq(0.5)
        expect(order.additional_tax_total).to eq(0o0)
      end
    end

    context 'tax excluded from price' do
      before do
        create(:adjustment,
               source: tax_rate,
               adjustable: line_item,
               order: order,
               included: false)
      end

      it 'tax applies to line item' do
        subject.update
        line_item.reload
        # Taxable amount is: $20 (base) - $10 (promotion) = $10
        # Tax rate is 5% (of $10).
        expect(line_item.included_tax_total).to eq(0)
        expect(line_item.additional_tax_total).to eq(0.5)
        expect(line_item.promo_total).to eq(-10)
        expect(line_item.adjustment_total).to eq(-9.5)
      end

      it 'tax linked to order' do
        order_subject.update
        order.reload
        expect(order.included_tax_total).to eq(0)
        expect(order.additional_tax_total).to eq(0.5)
      end
    end
  end
end
